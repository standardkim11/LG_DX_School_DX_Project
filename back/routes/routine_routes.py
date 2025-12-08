from flask import Blueprint, request, jsonify
from datetime import datetime, date, timedelta

from Project.extensions import db
from models import User, Routine, RoutineExecution
from routes.maping import normalize_routine_name, parse_preferred_time

routine_bp = Blueprint("routine", __name__, url_prefix="/api")


# 공통 직렬화 함수 --------------------
def routine_to_dict(r: Routine) -> dict:
    return {
        "id": r.id,
        "user_id": r.user_id,
        "name": r.name,
        "routine_type": r.routine_type,
        "run_minutes": r.run_minutes,
        "schedule_type": r.schedule_type,
        "preferred_time": r.preferred_time,
        "is_active": r.is_active,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }


def execution_to_dict(e: RoutineExecution) -> dict:
    return {
        "id": e.id,
        "user_id": e.user_id,
        "routine_id": e.routine_id,
        "status": e.status,
        "start_time": e.start_time.isoformat() if e.start_time else None,
        "end_time": e.end_time.isoformat() if e.end_time else None,
        "run_time": e.run_time,
        "recommended_flag": e.recommended_flag,
        "priority_score": e.priority_score,
    }


# 0. 루틴 생성 ------------------------------------
@routine_bp.post("/routines")
def create_routine():
    """
    새 루틴 생성
    POST /api/routines
    Body: {
        "user_id": 1,
        "name": "루틴 이름",
        "routine_type": "CLEANING",
        "schedule_type": "DAILY",
        "preferred_time": "09:30",
        "run_minutes": 30
    }
    """
    data = request.get_json() or {}

    user_id = data.get("user_id", 1)
    name = data.get("name", "").strip()

    if not name:
        return jsonify({"error": "name is required"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "user not found"}), 404

    # 루틴 타입 기본값 처리
    routine_type = data.get("routine_type", "ETC")
    if not routine_type:
        routine_type = "ETC"

    # 스케줄 타입 기본값 처리
    schedule_type = data.get("schedule_type", "DAILY")
    if not schedule_type:
        schedule_type = "DAILY"

    # preferred_time 처리
    preferred_time = data.get("preferred_time")

    # run_minutes 처리
    run_minutes = data.get("run_minutes")
    if run_minutes is not None:
        try:
            run_minutes = int(run_minutes)
        except (ValueError, TypeError):
            run_minutes = None

    # run_minutes가 없으면 루틴 타입별 기본값 사용
    if run_minutes is None:
        from .maping import get_default_run_minutes
        run_minutes = get_default_run_minutes(routine_type)

    new_routine = Routine(
        user_id=user.id,
        name=name,
        routine_type=routine_type,
        schedule_type=schedule_type,
        preferred_time=preferred_time,
        run_minutes=run_minutes,
        is_active=True,
    )

    db.session.add(new_routine)
    db.session.commit()

    return jsonify(routine_to_dict(new_routine)), 201


# 1. 루틴 목록 조회 (집계 정보 포함) ------------------------------------
@routine_bp.get("/routines")
def list_routines():
    """
    전체 루틴 목록 조회 (VIEW ALL 화면용)
    집계 정보(완료 횟수 등)를 포함하여 반환
    GET /api/routines?user_id=1
    """
    user_id = request.args.get("user_id", type=int, default=1)

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "user not found"}), 404

    routines = (
        Routine.query.filter_by(user_id=user_id, is_active=True)
        .order_by(Routine.created_at.desc())
        .all()
    )

    # 집계 정보 포함하여 반환
    result = []
    for r in routines:
        # 완료 횟수 집계 (status가 "2" 또는 2인 것만 카운트)
        # DB에서 status가 문자열로 저장될 수도 있고 숫자로 저장될 수도 있음
        all_executions = (
            RoutineExecution.query
            .filter_by(user_id=user_id, routine_id=r.id)
            .all()
        )
        
        completed_count = 0
        for exec in all_executions:
            # status가 문자열 "2"이거나 숫자 2인 경우 모두 체크
            if str(exec.status) == "2" or exec.status == 2:
                completed_count += 1
        
        # 오늘 완료 여부 확인
        today = date.today()
        today_start = datetime.combine(today, datetime.min.time())
        today_end = datetime.combine(today + timedelta(days=1), datetime.min.time())
        
        today_executions = [
            exec for exec in all_executions
            if exec.start_time and today_start <= exec.start_time < today_end
            and (str(exec.status) == "2" or exec.status == 2)
        ]
        
        routine_dict = routine_to_dict(r)
        routine_dict["completed_count"] = completed_count
        routine_dict["is_done_today"] = len(today_executions) > 0
        
        result.append(routine_dict)

    return jsonify(result)


# 2. 루틴 실행(완료/스킵) 기록 -------------------------------
@routine_bp.post("/routine-executions")
def create_routine_execution():
    data = request.get_json() or {}

    user_id = data.get("user_id", 1)
    routine_id = data.get("routine_id")
    status = (data.get("status") or "").upper()
    run_minutes = data.get("run_minutes")

    if not routine_id:
        return jsonify({"error": "routine_id is required"}), 400
    if status not in {"COMPLETED", "SKIPPED"}:
        return jsonify({"error": "status must be COMPLETED or SKIPPED"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "user not found"}), 404

    routine = Routine.query.get(routine_id)
    if not routine or routine.user_id != user.id:
        return jsonify({"error": "routine not found for this user"}), 404

    start_time = datetime.utcnow()
    end_time = None

    if run_minutes is not None:
        try:
            run_minutes = int(run_minutes)
        except Exception:
            return jsonify({"error": "run_minutes must be integer"}), 400

        end_time = start_time + timedelta(minutes=run_minutes)

    exec_log = RoutineExecution(
        user_id=user.id,
        routine_id=routine.id,
        status=status,
        start_time=start_time,
        end_time=end_time,
        run_time=run_minutes,
        recommended_flag=0,
        priority_score=None,
    )

    db.session.add(exec_log)
    db.session.commit()

    return jsonify(execution_to_dict(exec_log)), 201


# 3. 오늘 체크리스트 조회 --------------------------------
@routine_bp.get("/today-checklist")
def today_checklist():
    user_id = request.args.get("user_id", type=int, default=1)

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "user not found"}), 404

    today = date.today()
    start = datetime.combine(today, datetime.min.time())
    end = start + timedelta(days=1)

    routines = (
        Routine.query.filter_by(user_id=user_id, is_active=True)
        .order_by(Routine.created_at.desc())
        .all()
    )

    routine_ids = [r.id for r in routines]

    executions = (
        RoutineExecution.query.filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.routine_id.in_(routine_ids),
            RoutineExecution.start_time >= start,
            RoutineExecution.start_time < end,
        )
        .order_by(
            RoutineExecution.routine_id,
            RoutineExecution.start_time.desc(),
        )
        .all()
    )

    latest_by_routine = {}
    for e in executions:
        if e.routine_id not in latest_by_routine:
            latest_by_routine[e.routine_id] = e

    items = []
    for r in routines:
        exec_log = latest_by_routine.get(r.id)
        status = exec_log.status if exec_log else "PENDING"

        items.append(
            {
                "routine": routine_to_dict(r),
                "status": status,
                "execution_id": exec_log.id if exec_log else None,
            }
        )

    return jsonify(items)
