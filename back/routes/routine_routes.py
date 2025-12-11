from flask import Blueprint, request, jsonify
from datetime import datetime, date, timedelta
from sqlalchemy import func, case

from Project.extensions import db
from models import User, Routine, RoutineExecution, RoutineTimeOverride
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
        "schedule_frequency": r.schedule_frequency,
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

    # schedule_frequency 처리 (기본값 1)
    schedule_frequency = data.get("schedule_frequency", 1)
    if schedule_frequency is not None:
        try:
            schedule_frequency = int(schedule_frequency)
            if schedule_frequency < 1:
                schedule_frequency = 1
        except (ValueError, TypeError):
            schedule_frequency = 1
    else:
        schedule_frequency = 1

    new_routine = Routine(
        user_id=user.id,
        name=name,
        routine_type=routine_type,
        schedule_type=schedule_type,
        schedule_frequency=schedule_frequency,
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
    목표 달성된 WEEKLY/MONTHLY 루틴은 필터링하여 제외
    GET /api/routines?user_id=1&date=2024-01-15 (날짜 파라미터 선택, 없으면 오늘 날짜)
    """
    user_id = request.args.get("user_id", type=int, default=1)
    date_str = request.args.get("date")  # 선택된 날짜 (YYYY-MM-DD 형식)

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "user not found"}), 404

    routines = (
        Routine.query.filter_by(user_id=user_id, is_active=True)
        .order_by(Routine.created_at.desc())
        .all()
    )

    if not routines:
        return jsonify([])
    
    # 목표 달성된 WEEKLY/MONTHLY 루틴 필터링
    from .maping import is_scheduled_today
    
    # 날짜 파싱 (없으면 오늘 날짜) - 한 번만 파싱
    if date_str:
        try:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            target_date = date.today()
    else:
        target_date = date.today()
    
    # 성능 최적화: 모든 WEEKLY/MONTHLY 루틴의 목표 달성 여부를 배치로 조회
    weekly_routines = []
    monthly_routines = []
    daily_routines = []
    other_routines = []
    
    for r in routines:
        st = (r.schedule_type or "").upper()
        if st == "DAILY":
            daily_routines.append(r)
        elif st == "WEEKLY":
            weekly_routines.append(r)
        elif st == "MONTHLY":
            monthly_routines.append(r)
        else:
            other_routines.append(r)
    
    # WEEKLY 루틴 목표 달성 여부 배치 조회
    goal_achieved_map = {}
    if weekly_routines:
        # 이번 주 시작일 계산 (target_date 기준)
        weekday = target_date.weekday()
        week_start = target_date - timedelta(days=weekday)
        week_start_dt = datetime.combine(week_start, datetime.min.time())
        week_end_dt = datetime.combine(week_start + timedelta(days=7), datetime.min.time())
        
        weekly_ids = [r.id for r in weekly_routines]
        # 각 루틴의 이번 주 완료 횟수와 목표 빈도 가져오기
        weekly_completed_counts = (
            db.session.query(
                RoutineExecution.routine_id,
                func.count(RoutineExecution.id).label('count')
            )
            .filter(
                RoutineExecution.user_id == user_id,
                RoutineExecution.routine_id.in_(weekly_ids),
                RoutineExecution.start_time >= week_start_dt,
                RoutineExecution.start_time < week_end_dt,
                RoutineExecution.status == 2
            )
            .group_by(RoutineExecution.routine_id)
            .all()
        )
        completed_count_map = {rid: count for rid, count in weekly_completed_counts}
        
        for r in weekly_routines:
            completed_count = completed_count_map.get(r.id, 0)
            frequency = getattr(r, 'schedule_frequency', 1) or 1
            goal_achieved_map[r.id] = completed_count >= frequency
    
    # MONTHLY 루틴 목표 달성 여부 배치 조회
    if monthly_routines:
        monthly_ids = [r.id for r in monthly_routines]
        # 각 MONTHLY 루틴의 created_at과 frequency 정보 수집
        monthly_info = {}
        for r in monthly_routines:
            created = r.created_at.date() if r.created_at else target_date
            created_dt = datetime.combine(created, datetime.min.time())
            period_end = created + timedelta(days=30)
            period_end_dt = datetime.combine(period_end, datetime.min.time())
            frequency = getattr(r, 'schedule_frequency', 1) or 1
            monthly_info[r.id] = {
                'created_dt': created_dt,
                'period_end_dt': period_end_dt,
                'frequency': frequency
            }
        
        # 모든 MONTHLY 루틴의 완료 횟수 배치 조회
        monthly_completed_counts = {}
        for rid, info in monthly_info.items():
            completed_count = (
                db.session.query(func.count(RoutineExecution.id))
                .filter(
                    RoutineExecution.user_id == user_id,
                    RoutineExecution.routine_id == rid,
                    RoutineExecution.start_time >= info['created_dt'],
                    RoutineExecution.start_time < info['period_end_dt'],
                    RoutineExecution.status == 2
                )
                .scalar() or 0
            )
            monthly_completed_counts[rid] = completed_count
        
        # 목표 달성된 루틴의 마지막 완료 날짜 조회 (배치)
        achieved_monthly_ids = [
            rid for rid in monthly_ids 
            if monthly_completed_counts.get(rid, 0) >= monthly_info[rid]['frequency']
        ]
        
        # 목표 달성되지 않은 루틴은 False로 설정
        for rid in monthly_ids:
            if rid not in achieved_monthly_ids:
                goal_achieved_map[rid] = False
        
        if achieved_monthly_ids:
            # 모든 목표 달성된 MONTHLY 루틴의 마지막 완료 날짜를 한 번에 조회
            # 각 루틴별로 다른 날짜 범위를 사용하므로, 각 루틴별로 조회해야 하지만
            # 가능한 경우 배치 최적화
            last_completed_dates = {}
            
            # 각 루틴의 마지막 완료 날짜를 조회 (날짜 범위가 달라서 완전한 배치는 어려움)
            # 하지만 루프 내에서 쿼리를 최적화
            for rid in achieved_monthly_ids:
                info = monthly_info[rid]
                last_completed = (
                    RoutineExecution.query
                    .filter(
                        RoutineExecution.user_id == user_id,
                        RoutineExecution.routine_id == rid,
                        RoutineExecution.start_time >= info['created_dt'],
                        RoutineExecution.start_time < info['period_end_dt'],
                        RoutineExecution.status == 2
                    )
                    .order_by(RoutineExecution.start_time.desc())
                    .first()
                )
                if last_completed and last_completed.start_time:
                    last_completed_dates[rid] = last_completed.start_time.date()
            
            # 목표 달성 여부 최종 판단
            for rid in achieved_monthly_ids:
                last_date = last_completed_dates.get(rid)
                if last_date:
                    # 마지막 완료 날짜의 다음날부터는 더 이상 표시하지 않음
                    goal_achieved_map[rid] = target_date > last_date
                else:
                    # 완료 기록이 있지만 날짜 정보가 없으면 목표 달성으로 간주
                    goal_achieved_map[rid] = True
    
    # 필터링된 루틴 리스트 구성
    # VIEW ALL 화면에서는 목표 달성 여부만 체크하고, 스케줄 여부는 체크하지 않음
    # (사용자가 언제든지 루틴을 선택할 수 있도록)
    filtered_routines = []
    filtered_routines.extend(daily_routines)
    filtered_routines.extend(other_routines)
    
    for r in weekly_routines:
        goal_achieved = goal_achieved_map.get(r.id, False)
        # 목표 달성되지 않은 루틴만 표시 (스케줄 여부는 체크하지 않음)
        if not goal_achieved:
            filtered_routines.append(r)
    
    for r in monthly_routines:
        goal_achieved = goal_achieved_map.get(r.id, False)
        # 목표 달성되지 않은 루틴만 표시 (스케줄 여부는 체크하지 않음)
        if not goal_achieved:
            filtered_routines.append(r)
    
    routines = filtered_routines

    routine_ids = [r.id for r in routines]
    
    # 날짜 범위 계산 (target_date는 이미 위에서 파싱됨)
    date_start = datetime.combine(target_date, datetime.min.time())
    date_end = datetime.combine(target_date + timedelta(days=1), datetime.min.time())

    # 한 번의 쿼리로 모든 루틴의 완료 횟수 집계 (status는 숫자로 저장됨: 2=완료)
    # Oracle에서는 숫자 컬럼과 문자열 비교 시 타입 오류 발생하므로 숫자만 비교
    completed_counts = (
        db.session.query(
            RoutineExecution.routine_id,
            func.count(RoutineExecution.id).label('count')
        )
        .filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.routine_id.in_(routine_ids),
            RoutineExecution.status == 2  # 숫자 2만 비교 (완료 상태)
        )
        .group_by(RoutineExecution.routine_id)
        .all()
    )
    
    # 완료 횟수 딕셔너리로 변환
    completed_count_map = {routine_id: count for routine_id, count in completed_counts}
    
    # 한 번의 쿼리로 해당 날짜에 완료된 루틴 ID 목록 가져오기 (status는 숫자로 저장됨: 2=완료)
    # Oracle에서는 숫자 컬럼과 문자열 비교 시 타입 오류 발생하므로 숫자만 비교
    date_completed_routine_ids = (
        db.session.query(RoutineExecution.routine_id)
        .filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.routine_id.in_(routine_ids),
            RoutineExecution.start_time >= date_start,
            RoutineExecution.start_time < date_end,
            RoutineExecution.status == 2  # 숫자 2만 비교 (완료 상태)
        )
        .distinct()
        .all()
    )
    
    # 해당 날짜에 완료된 루틴 ID 집합으로 변환
    date_completed_set = {row[0] for row in date_completed_routine_ids}

    # 해당 날짜의 시간 오버라이드 조회 (배치)
    routine_ids_list = [r.id for r in routines]
    date_overrides = {}
    if routine_ids_list:
        overrides = RoutineTimeOverride.query.filter(
            RoutineTimeOverride.routine_id.in_(routine_ids_list),
            RoutineTimeOverride.override_date == target_date
        ).all()
        date_overrides = {ov.routine_id: ov.override_time for ov in overrides}

    # WEEKLY 루틴의 이번 주 완료 횟수 계산
    weekly_completed_count_map = {}
    weekly_routine_ids = [r.id for r in routines if (r.schedule_type or "").upper() == "WEEKLY"]
    if weekly_routine_ids:
        # 이번 주 시작일 계산 (월요일)
        weekday = target_date.weekday()  # 0=월요일, 6=일요일
        week_start = target_date - timedelta(days=weekday)
        week_start_dt = datetime.combine(week_start, datetime.min.time())
        week_end_dt = datetime.combine(week_start + timedelta(days=7), datetime.min.time())
        
        # 이번 주 완료 횟수 집계 (status는 숫자로 저장됨: 2=완료)
        weekly_completed_counts = (
            db.session.query(
                RoutineExecution.routine_id,
                func.count(RoutineExecution.id).label('count')
            )
            .filter(
                RoutineExecution.user_id == user_id,
                RoutineExecution.routine_id.in_(weekly_routine_ids),
                RoutineExecution.start_time >= week_start_dt,
                RoutineExecution.start_time < week_end_dt,
                RoutineExecution.status == 2  # 숫자 2만 비교 (완료 상태)
            )
            .group_by(RoutineExecution.routine_id)
            .all()
        )
        
        weekly_completed_count_map = {routine_id: count for routine_id, count in weekly_completed_counts}
    
    # 집계 정보 포함하여 반환
    result = []
    for r in routines:
        routine_dict = routine_to_dict(r)
        routine_dict["completed_count"] = completed_count_map.get(r.id, 0)
        routine_dict["is_done_today"] = r.id in date_completed_set
        # 해당 날짜의 오버라이드 시간이 있으면 추가
        if r.id in date_overrides:
            routine_dict["override_time"] = date_overrides[r.id]
        # WEEKLY 루틴의 경우 이번 주 완료 횟수 추가
        if (r.schedule_type or "").upper() == "WEEKLY":
            routine_dict["weekly_completed_count"] = weekly_completed_count_map.get(r.id, 0)
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


# 4. 루틴 시간 오버라이드 저장/수정 --------------------------------
@routine_bp.post("/routine-time-override")
def set_routine_time_override():
    """
    특정 날짜에 루틴 시간을 오버라이드 (오늘만 시간 변경)
    POST /api/routine-time-override
    Body: {
        "routine_id": 1,
        "override_date": "2024-01-15",  # YYYY-MM-DD 형식
        "override_time": "17:00"  # HH:MM 형식
    }
    """
    data = request.get_json() or {}
    
    routine_id = data.get("routine_id")
    override_date_str = data.get("override_date")
    override_time = data.get("override_time")
    
    if not routine_id:
        return jsonify({"error": "routine_id is required"}), 400
    if not override_date_str:
        return jsonify({"error": "override_date is required"}), 400
    if not override_time:
        return jsonify({"error": "override_time is required"}), 400
    
    # 날짜 파싱
    try:
        override_date = datetime.strptime(override_date_str, "%Y-%m-%d").date()
    except ValueError:
        return jsonify({"error": "Invalid date format. Use YYYY-MM-DD"}), 400
    
    # 시간 형식 검증 (HH:MM)
    if not isinstance(override_time, str) or not override_time.count(':') == 1:
        return jsonify({"error": "Invalid time format. Use HH:MM"}), 400
    
    try:
        time_parts = override_time.split(':')
        hour = int(time_parts[0])
        minute = int(time_parts[1])
        if not (0 <= hour <= 23 and 0 <= minute <= 59):
            return jsonify({"error": "Invalid time values"}), 400
    except (ValueError, IndexError):
        return jsonify({"error": "Invalid time format. Use HH:MM"}), 400
    
    # 루틴 존재 확인
    routine = Routine.query.get(routine_id)
    if not routine:
        return jsonify({"error": "routine not found"}), 404
    
    # 기존 오버라이드 확인 (있으면 업데이트, 없으면 생성)
    existing_override = RoutineTimeOverride.query.filter_by(
        routine_id=routine_id,
        override_date=override_date
    ).first()
    
    if existing_override:
        existing_override.override_time = override_time
    else:
        new_override = RoutineTimeOverride(
            routine_id=routine_id,
            override_date=override_date,
            override_time=override_time
        )
        db.session.add(new_override)
    
    db.session.commit()
    
    return jsonify({
        "success": True,
        "message": "루틴 시간 오버라이드가 저장되었습니다.",
        "routine_id": routine_id,
        "override_date": override_date_str,
        "override_time": override_time
    }), 200


# 5. 루틴 시간 오버라이드 삭제 --------------------------------
@routine_bp.delete("/routine-time-override")
def delete_routine_time_override():
    """
    특정 날짜의 루틴 시간 오버라이드 삭제
    DELETE /api/routine-time-override?routine_id=1&override_date=2024-01-15
    """
    routine_id = request.args.get("routine_id", type=int)
    override_date_str = request.args.get("override_date")
    
    if not routine_id:
        return jsonify({"error": "routine_id is required"}), 400
    if not override_date_str:
        return jsonify({"error": "override_date is required"}), 400
    
    # 날짜 파싱
    try:
        override_date = datetime.strptime(override_date_str, "%Y-%m-%d").date()
    except ValueError:
        return jsonify({"error": "Invalid date format. Use YYYY-MM-DD"}), 400
    
    # 오버라이드 삭제
    override = RoutineTimeOverride.query.filter_by(
        routine_id=routine_id,
        override_date=override_date
    ).first()
    
    if override:
        db.session.delete(override)
        db.session.commit()
        return jsonify({
            "success": True,
            "message": "루틴 시간 오버라이드가 삭제되었습니다."
        }), 200
    else:
        return jsonify({
            "success": False,
            "message": "오버라이드를 찾을 수 없습니다."
        }), 404
