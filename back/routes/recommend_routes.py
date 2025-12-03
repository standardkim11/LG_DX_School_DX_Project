from flask import Blueprint, current_app, request, jsonify
from datetime import datetime, time, date, timedelta
import pandas as pd  # type: ignore
from sqlalchemy.exc import DatabaseError  # type: ignore
from Project.extensions import db
from models import User, Routine, Notification, RoutineExecution , UserDevice  ,WeatherInfo, DeviceLog
import re

from .maping import encode_routine_type, encode_schedule_type, encode_weather, REVERSE_ROUTINE_TYPE, REVERSE_SCHEDULE_TYPE, REVERSE_WEATHER
from .maping import parse_preferred_time,    is_scheduled_today,    is_done_today, is_failed_today, normalize_routine_name
from .utils import distance_km, today_date, safe_commit, error_response


recommend_bp = Blueprint("recommend", __name__)


@recommend_bp.route("/hello", methods=["GET"])
def hello():
    return jsonify({"message": "Hello from Flask modular app"})


@recommend_bp.route("/context-event", methods=["POST"])
def context_event():
    """
    귀가 시점 상황 기반 추천 API

    - 집(등록 지점) 근처로 도착했을 때
    - 평소 도착 시간보다 몇 분 늦었는지/일찍 왔는지 안내하고
    - 도착 후 먼저 하면 좋은 루틴(우선순위 점수 + 소요시간 짧은 순)을 추천
    """
    data = request.get_json() or {}

    user_id = data.get("user_id", 1)
    # 예전 payload 호환용: event_type 또는 context 둘 다 허용
    event_type = data.get("event_type") or data.get("context")
    cur_lat = data.get("current_lat")
    cur_lng = data.get("current_lng")

    # event_type 없으면 기본값으로 ARRIVE_HOME 처리 (있으면 그대로 사용)
    if not event_type:
        event_type = "ARRIVE_HOME"

    # 귀가 상황만 처리 (필요하면 향후 EVENT_TYPE 늘리기)
    if event_type not in ("ARRIVE_HOME", "HOME_AFTER_WORK"):
        return jsonify({
            "triggered": False,
            "message": "unsupported event_type"
        }), 400

    # 현재 위치 필수
    if cur_lat is None or cur_lng is None:
        return jsonify({
            "triggered": False,
            "message": "current_lat / current_lng required"
        }), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"triggered": False, "message": "user not found"}), 404

    if user.home_lat is None or user.home_lng is None:
        return jsonify({
            "triggered": False,
            "message": "user home location not set"
        }), 400

    # 1) 집과의 거리 계산 (km)
    dist_km = distance_km(
        float(cur_lat), float(cur_lng),
        float(user.home_lat), float(user.home_lng)
    )

    # 예: 집 반경 3km 이내면 귀가 시점으로 판단
    THRESHOLD_KM = 3.0
    if dist_km > THRESHOLD_KM:
        return jsonify({
            "triggered": False,
            "distance_km": dist_km,
            "message": f"집까지 아직 멀어요 (약 {dist_km:.1f} km 남음)"
        })

    # 2) 평소 도착 시간 대비 몇 분 차이 나는지 계산
    # TODO: 나중에는 user 프로필에서 '평소 귀가 시간'을 읽도록 변경 가능
    baseline_home_time = time(19, 0)  # 예: 저녁 7시를 평소 도착 시간으로 가정
    now = datetime.now()
    baseline_dt = datetime.combine(now.date(), baseline_home_time)
    diff_minutes = int((now - baseline_dt).total_seconds() // 60)

    if diff_minutes > 0:
        lateness_message = f"오늘은 평소보다 {diff_minutes}분 늦게 들어오시는 길이에요."
    elif diff_minutes < 0:
        lateness_message = f"오늘은 평소보다 {-diff_minutes}분 일찍 들어오시는 길이에요."
    else:
        lateness_message = "오늘은 평소와 거의 비슷한 시간에 귀가 중이에요."

    # 3) 여기서부터는 priority와 거의 동일한 로직으로 점수 계산
    model = current_app.model  # type: ignore
    feature_cols = current_app.feature_cols  # type: ignore

    if model is None or feature_cols is None:
        return jsonify({
            "triggered": False,
            "message": "ML model not loaded"
        }), 500

    exec_hour = now.hour
    exec_dow = now.weekday()
    today = now.date()

    # 오늘 활성 루틴 조회 + 오늘 스케줄/미완료 필터
    try:
        all_routines = Routine.query.filter_by(
            user_id=user_id, is_active=True
        ).all()
    except DatabaseError as e:
        error_msg = str(e.orig) if hasattr(e, "orig") else str(e)
        return jsonify({
            "triggered": False,
            "message": "Unable to query routines.",
            "details": error_msg
        }), 503

    routines = []
    for r in all_routines:
        if not is_scheduled_today(r, today):
            continue
        if is_done_today(r, user_id, today):
            continue
        # 추천에서는 실패한 루틴 제외
        if is_failed_today(r, user_id, today):
            continue
        routines.append(r)

    if not routines:
        return jsonify({
            "triggered": True,
            "distance_km": dist_km,
            "lateness_minutes": diff_minutes,
            "lateness_message": lateness_message,
            "message": "오늘 추천할 루틴이 없습니다.",
            "recommendations": []
        })

    # 날씨 정보 (priority와 동일하게 처리)
    weather = WeatherInfo.query.filter_by(date=today).first()
    temp = float(weather.temperature) if weather and weather.temperature else 20.0
    humi = float(weather.humidity) if weather and weather.humidity else 60.0
    weather_code = encode_weather(weather.weather) if weather and weather.weather is not None else 0
    pm25 = float(weather.pm25) if weather and weather.pm25 else 40.0
    pm10 = float(weather.pm10) if weather and weather.pm10 else 60.0

    # 4) 모델 input rows 생성
    rows = []
    for r in routines:
        rt = encode_routine_type(r.routine_type)
        st = encode_schedule_type(r.schedule_type)
        preferred_hour = parse_preferred_time(r.preferred_time)

        last_log = RoutineExecution.query.filter_by(
            user_id=user_id, routine_id=r.id
        ).order_by(RoutineExecution.start_time.desc()).first()

        if last_log:
            run_time = int(last_log.run_time or r.run_minutes or 30)
            recommended_flag = int(bool(last_log.recommended_flag))
        else:
            run_time = int(r.run_minutes or 30)
            recommended_flag = 0

        rows.append({
            "ROUTINE_ID": r.id,
            "ROUTINE_NAME": r.name,
            "ROUTINE_TYPE": rt,
            "SCHEDULE_TYPE": st,
            "PREFERRED_TIME": preferred_hour,
            "RUN_TIME": run_time,
            "EXEC_HOUR": exec_hour,
            "EXEC_DOW": exec_dow,
            "RUN_MINUTES": int(r.run_minutes or 30),
            "RECOMMENDED_FLAG": recommended_flag,
            "TEMPERATURE": temp,
            "HUMIDITY": humi,
            "WEATHER": weather_code,
            "PM25": pm25,
            "PM10": pm10,
        })

    df = pd.DataFrame(rows)

    # feature_cols 체크
    missing = [c for c in feature_cols if c not in df.columns]
    if missing:
        return jsonify({
            "triggered": False,
            "message": "missing features",
            "missing": missing
        }), 500

    X = df[feature_cols]
    preds = model.predict(X)
    df["pred_priority_score"] = preds

    # 5) 도착 후 먼저 해야 할 루틴:
    #    - pred_priority_score 내림차순
    #    - 같은 점수면 RUN_MINUTES(소요 시간) 짧은 순
    df_sorted = df.sort_values(
        ["pred_priority_score", "RUN_MINUTES"],
        ascending=[False, True]
    )        # 오늘 완료 여부 체크
        last_log = (
            RoutineExecution.query
            .filter_by(user_id=user_id, routine_id=r.id)
            .order_by(RoutineExecution.start_time.desc())
            .first()
        )

        done = False
        if last_log and last_log.start_time and last_log.start_time.date() == today:
            done = (last_log.status == 2)  # DONE


    TOP_K = 3
    top_df = df_sorted.head(TOP_K)

    result = []
    for _, row in df_sorted.iterrows():
        rt_code = int(row["ROUTINE_TYPE"])
        st_code = int(row["SCHEDULE_TYPE"])

        result.append({
            "routine_id": int(row["ROUTINE_ID"]),
            "routine_name": normalize_routine_name(str(row["ROUTINE_NAME"])),
            "pred_priority_score": float(row["pred_priority_score"]),
            "run_minutes": int(row["RUN_MINUTES"]),
            "routine_type": rt_code,
            "schedule_type": st_code,
            "routine_type_label": REVERSE_ROUTINE_TYPE.get(rt_code),
            "schedule_type_label": REVERSE_SCHEDULE_TYPE.get(st_code),
            "weather_label": REVERSE_WEATHER.get(weather_code),
        })


    return jsonify({
        "triggered": True,
        "distance_km": dist_km,
        "lateness_minutes": diff_minutes,
        "lateness_message": lateness_message,
        "message": "집에 도착하시면 이 순서로 루틴을 수행해보세요요.",
        "recommendations": recommendations
    })





@recommend_bp.route("/priority", methods=["GET"])
def get_priority_today():
    """
    오늘 사용자의 루틴을 불러와서 XGBoost 모델로 우선순위를 계산하는 API
    GET /api/priority?user_id=1&top_k=5
    """
    model = current_app.model  # type: ignore
    feature_cols = current_app.feature_cols  # type: ignore

    if model is None or feature_cols is None:
        return jsonify({"error": "ML model not loaded"}), 500

    # 쿼리 파라미터
    user_id = request.args.get("user_id", type=int, default=1)
    top_k = request.args.get("top_k", type=int, default=None)

    try:
        user = User.query.get(user_id)
    except DatabaseError as e:
        error_msg = str(e.orig) if hasattr(e, 'orig') else str(e)
        return jsonify({
            "error": "Database connection failed",
            "message": "Unable to connect to the database.",
            "details": error_msg,
            "hint": "Please check your .env file (DB_USER, DB_PASSWORD, DB_DSN)"
        }), 503
    
    if not user:
        # 사용자가 없으면 자동으로 생성
        user = User(
            id=user_id,
            email=f"demo{user_id}@test.com",
            name=f"테스트 사용자 {user_id}",
            address="서울시 강남구",
            home_lat=37.4979,
            home_lng=127.0276,
        )
        db.session.add(user)
        db.session.commit()
        current_app.logger.info(f"✅ 사용자 자동 생성 완료 (user_id={user_id})")

    now = datetime.now()
    exec_hour = now.hour
    exec_dow = now.weekday()
    today = now.date()

    # 오늘 활성 루틴 전체 조회
    try:
        all_routines = Routine.query.filter_by(user_id=user_id, is_active=True).all()
    except DatabaseError as e:
        error_msg = str(e.orig) if hasattr(e, 'orig') else str(e)
        return jsonify({
            "error": "Database query failed",
            "message": "Unable to query routines from the database.",
            "details": error_msg
        }), 503

    # 🔹 오늘 스케줄 & 아직 완료 안 된 루틴만 후보로 필터링
    routines = []
    for r in all_routines:
        if not is_scheduled_today(r, today):
            continue
        if is_done_today(r, user_id, today):
            continue
        # 추천에서는 실패한 루틴 제외
        if is_failed_today(r, user_id, today):
            continue
        routines.append(r)

    if not routines:
        return jsonify([])  # 오늘 추천할 루틴 없음


    # 날씨 가져오기 (없으면 default)
    weather = WeatherInfo.query.filter_by(date=today).first()
    temp = float(weather.temperature) if weather and weather.temperature else 20.0
    humi = float(weather.humidity) if weather and weather.humidity else 60.0
    weather_code = encode_weather(weather.weather) if weather and weather.weather is not None else 0
    pm25 = float(weather.pm25) if weather and weather.pm25 else 40.0
    pm10 = float(weather.pm10) if weather and weather.pm10 else 60.0

    rows = []

    rows = []

    for r in routines:
        # ROUTINE_TYPE (문자열/숫자 → 숫자)
        rt = encode_routine_type(r.routine_type)

        # SCHEDULE_TYPE (문자열/숫자 → 숫자)
        st = encode_schedule_type(r.schedule_type)

        # PREFERRED_TIME (문자열/숫자 → 시 단위 정수)
        preferred_hour = parse_preferred_time(r.preferred_time)

        # 최근 실행 기록
        last_log = RoutineExecution.query.filter_by(
            user_id=user_id, routine_id=r.id
        ).order_by(RoutineExecution.start_time.desc()).first()

        if last_log:
            run_time = int(last_log.run_time or r.run_minutes or 30)
            recommended_flag = int(bool(last_log.recommended_flag))
        else:
            run_time = int(r.run_minutes or 30)
            recommended_flag = 0

        rows.append({
            "ROUTINE_ID": r.id,
            "ROUTINE_NAME": r.name,

            # === ML 모델 Input Features ===
            "ROUTINE_TYPE": rt,
            "SCHEDULE_TYPE": st,
            "PREFERRED_TIME": preferred_hour,
            "RUN_TIME": run_time,
            "EXEC_HOUR": exec_hour,
            "EXEC_DOW": exec_dow,
            "RUN_MINUTES": int(r.run_minutes or 30),
            "RECOMMENDED_FLAG": recommended_flag,
            "TEMPERATURE": temp,
            "HUMIDITY": humi,
            "WEATHER": weather_code,
            "PM25": pm25,
            "PM10": pm10,
        })

    df = pd.DataFrame(rows)

    # feature 순서 맞추기
    missing = [c for c in feature_cols if c not in df.columns]
    if missing:
        return jsonify({"error": "missing features", "missing": missing}), 500

    X = df[feature_cols]
    preds = model.predict(X)
    df["pred_priority_score"] = preds

    df_sorted = df.sort_values("pred_priority_score", ascending=False)

    if top_k:
        df_sorted = df_sorted.head(top_k)

    # JSON 변환
    result = []
    for _, row in df_sorted.iterrows():
        result.append({
            "routine_id": int(row["ROUTINE_ID"]),
            "routine_name": normalize_routine_name(str(row["ROUTINE_NAME"])),
            "pred_priority_score": float(row["pred_priority_score"]),
            "run_minutes": int(row["RUN_MINUTES"]),
            "routine_type": int(row["ROUTINE_TYPE"]),
            "schedule_type": int(row["SCHEDULE_TYPE"]),
            "routine_type_label": REVERSE_ROUTINE_TYPE.get(rt),
            "schedule_type_label": REVERSE_SCHEDULE_TYPE.get(st),
            "weather_label": REVERSE_WEATHER.get(weather_code),

        })

    return jsonify(result)
    
@recommend_bp.route("/routines", methods=["POST"])
def create_routine():
    data = request.get_json() or {}

    user_id = data.get("user_id")
    name = data.get("name")
    routine_type = data.get("routine_type")
    schedule_type = data.get("schedule_type")
    preferred_time = data.get("preferred_time")
    run_minutes = data.get("run_minutes", 30)
    serial_no = data.get("serial_no")
    is_active = data.get("is_active", True)

    if not user_id or not name:
        return jsonify({"error": "user_id and name are required"}), 400

    routine = Routine(
        user_id=user_id,
        name=name,
        routine_type=routine_type,
        schedule_type=schedule_type,
        preferred_time=preferred_time,
        run_minutes=run_minutes,
        serial_no=serial_no,
        is_active=1 if is_active else 0,
        created_at=datetime.utcnow(),
    )
    db.session.add(routine)
    db.session.commit()

    return jsonify({"status": "ok", "routine_id": routine.id}), 201

@recommend_bp.route("/routines", methods=["GET"])
def list_routines():
    user_id = request.args.get("user_id", type=int)
    if not user_id:
        return jsonify({"error": "user_id required"}), 400

    routines = Routine.query.filter_by(user_id=user_id).all()

    return jsonify([
        {
            "id": r.id,
            "name": r.name,
            "routine_type": r.routine_type,
            "schedule_type": r.schedule_type,
            "preferred_time": r.preferred_time,
            "run_minutes": r.run_minutes,
            "serial_no": r.serial_no,
            "is_active": bool(r.is_active),
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in routines
    ])

@recommend_bp.route("/routines/<int:routine_id>", methods=["PATCH"])
def update_routine(routine_id):
    data = request.get_json() or {}

    routine = Routine.query.get(routine_id)
    if not routine:
        return jsonify({"error": "routine not found"}), 404

    for field in ["name", "routine_type", "schedule_type",
                  "preferred_time", "run_minutes", "serial_no"]:
        if field in data:
            setattr(routine, field, data[field])

    if "is_active" in data:
        routine.is_active = 1 if data["is_active"] else 0

    db.session.commit()
    return jsonify({"status": "ok"})

@recommend_bp.route("/routines/<int:routine_id>", methods=["DELETE"])
def delete_routine(routine_id):
    routine = Routine.query.get(routine_id)
    if not routine:
        return jsonify({"error": "routine not found"}), 404

    db.session.query(RoutineExecution).filter_by(routine_id=routine_id).delete()
    db.session.delete(routine)
    db.session.commit()

    return jsonify({"status": "ok"})

@recommend_bp.route("/routines/<int:routine_id>/execute", methods=["POST"])
def execute_routine(routine_id):
    data = request.get_json() or {}

    user_id = data.get("user_id")
    status = data.get("status", 2)  # 0=pending, 1=running, 2=done

    if not user_id:
        return jsonify({"error": "user_id required"}), 400

    routine = Routine.query.get(routine_id)
    if not routine:
        return jsonify({"error": "routine not found"}), 404

    start_time = datetime.utcnow()
    end_time = None
    run_time = data.get("run_time", routine.run_minutes)

    exec_log = RoutineExecution(
        user_id=user_id,
        routine_id=routine_id,
        status=status,
        start_time=start_time,
        end_time=end_time,
        run_time=run_time,
        recommended_flag=1,
        created_at=start_time,
    )
    db.session.add(exec_log)
    db.session.commit()

    return jsonify({"status": "ok", "execution_id": exec_log.id})

@recommend_bp.route("/routines/<int:routine_id>/deactivate", methods=["POST"])
def deactivate_routine(routine_id):
    routine = Routine.query.get(routine_id)
    if not routine:
        return jsonify({"error": "routine_not_found"}), 404

    # 이미 비활성화된 경우
    if not routine.is_active:
        return jsonify({"message": "already_inactive"}), 200

    routine.is_active = False
    db.session.commit()
    return jsonify({"message": "routine_deactivated", "routine_id": routine_id})

@recommend_bp.route("/routines/<int:routine_id>/fail", methods=["POST"])
def fail_routine(routine_id):
    user_id = request.args.get("user_id", type=int)
    if not user_id:
        return jsonify({"error": "user_id_required"}), 400

    routine = Routine.query.get(routine_id)
    if not routine or not routine.is_active:
        return jsonify({"error": "inactive_or_not_found"}), 404

    today = datetime.now().date()

    # 이미 오늘 수행 기록이 있다면 중복 실패 방지
    existing = (
        RoutineExecution.query
        .filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.routine_id == routine_id,
            RoutineExecution.start_time >= datetime.combine(today, time.min),
            RoutineExecution.start_time <= datetime.combine(today, time.max),
        )
        .first()
    )
    if existing:
        return jsonify({"message": "already_recorded", "status": existing.status}), 200

    # 실패 기록
    exec_log = RoutineExecution(
        user_id=user_id,
        routine_id=routine_id,
        status=3,   # FAILED
        start_time=datetime.now(),
        end_time=None,
        run_time=None,
        recommended_flag=0,
        priority_score=None,
        created_at=datetime.now()
    )
    db.session.add(exec_log)
    db.session.commit()

    return jsonify({"message": "routine_failed", "routine_id": routine_id})


@recommend_bp.route("/today-routines", methods=["GET"])
def get_today_routines():
    """
    오늘 해야 하는 루틴 리스트 API
    GET /api/recommend/today-routines?user_id=1
    """
    user_id = request.args.get("user_id", type=int)
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    now = datetime.now()
    today = now.date()

    # 1) 오늘 스케줄에 해당하며 active인 루틴 가져오기
    try:
        all_routines = Routine.query.filter_by(
            user_id=user_id,
            is_active=True
        ).all()
    except Exception as e:
        return jsonify({"error": "DB error", "details": str(e)}), 500

    today_list = []
    for r in all_routines:
        # 오늘 스케줄인지 검사
        if not is_scheduled_today(r, today):
            continue

        # 오늘 완료 여부 체크
                # 오늘 완료 / 실패 여부 체크
        last_log = (
            RoutineExecution.query
            .filter_by(user_id=user_id, routine_id=r.id)
            .order_by(RoutineExecution.start_time.desc())
            .first()
        )

        done = False
        failed = False
        if last_log and last_log.start_time and last_log.start_time.date() == today:
            if last_log.status == 2:      # DONE
                done = True
            elif last_log.status == 3:    # FAILED
                failed = True

        # preferred_time → 정렬용 숫자
        pref_hour = parse_preferred_time(r.preferred_time)

        today_list.append({
            "routine_id": r.id,
            "name": normalize_routine_name(r.name),
            "routine_type": r.routine_type,
            "schedule_type": r.schedule_type,
            "preferred_time": r.preferred_time,
            "preferred_hour": pref_hour,
            "run_minutes": r.run_minutes,
            "done": done,
            "failed": failed,   # ← 추가
        })


    # 2) 정렬: preferred_time 기준
    today_list.sort(key=lambda x: x["preferred_hour"])

    return jsonify(today_list)

@recommend_bp.route("/dashboard", methods=["GET"])
def get_dashboard():
    """대시보드 화면용 요약 API.

    쿼리 파라미터:
    - user_id (필수)
    - year, month (옵션: 없으면 현재 연/월 기준)

    응답 예:
    {
      "user_id": 1,
      "year": 2025,
      "month": 12,
      "monthly_summary": {
        "success_rate": 0.84,
        "completed_count": 32,
        "failed_count": 2,
        "postponed_count": 4
      },
      "habit": {
        "enabled": true,
        "routine_id": 9001,
        "title": "아침에 물 마시기",
        "display_name": "물 마시기",
        "goal_days": 21,
        "done_days": 5,
        "remaining_days": 16,
        "progress_rate": 0.75
      }
    }
    """
    user_id = request.args.get("user_id", type=int)
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    # 기준 연/월 결정 (파라미터 없으면 현재)
    now = datetime.now()
    year = request.args.get("year", type=int) or now.year
    month = request.args.get("month", type=int) or now.month

    # 월의 시작/끝 datetime 계산
    start_dt = datetime(year, month, 1)
    if month == 12:
        next_month_dt = datetime(year + 1, 1, 1)
    else:
        next_month_dt = datetime(year, month + 1, 1)

    # -------------------------------
    # 1) 월간 실행 로그 집계
    # -------------------------------
    logs = (
        RoutineExecution.query
        .filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.start_time >= start_dt,
            RoutineExecution.start_time < next_month_dt,
        )
        .all()
    )

    # status 값은 프로젝트에서 쓰는 규칙에 맞게 수정 가능
    completed_count = sum(1 for log in logs if log.status == 2)  # DONE
    failed_count = sum(1 for log in logs if log.status == 3)     # FAILED

    
    # 미룬 루틴 수(postponed)는 서비스 룰이 정해지면 여기서 계산 방식만 바꾸면 됨
    postponed_count = 0

    denom = completed_count + failed_count + postponed_count
    success_rate = (completed_count / denom) if denom > 0 else None

    monthly_summary = {
        "success_rate": success_rate,
        "completed_count": completed_count,
        "failed_count": failed_count,
        "postponed_count": postponed_count,
    }

    # -------------------------------
    # 2) 습관 카드 정보 계산
    # -------------------------------
    habit_info = {
        "enabled": False,
        "routine_id": None,
        "title": None,
        "display_name": None,
        "goal_days": None,
        "done_days": None,
        "remaining_days": None,
        "progress_rate": None,
    }

    # 습관 트래킹 설정( habit_goal_days )이 된 루틴 중 하나 선택
    habit_routine = (
        Routine.query
        .filter(
            Routine.user_id == user_id,
            Routine.is_active == True,
            Routine.habit_goal_days.isnot(None),
        )
        .order_by(Routine.habit_start_date.asc())
        .first()
    )

    if habit_routine and habit_routine.habit_goal_days:
        goal_days = int(habit_routine.habit_goal_days)
        # 시작일 없으면 월 시작일로 대체
        start_date = habit_routine.habit_start_date or start_dt.date()

        # 해당 루틴의 완료 로그에서 "완료한 날짜 수" 계산
        habit_logs = (
            RoutineExecution.query
            .filter(
                RoutineExecution.user_id == user_id,
                RoutineExecution.routine_id == habit_routine.id,
                RoutineExecution.status == 2,  # DONE
                RoutineExecution.start_time >= datetime.combine(start_date, time.min),
                RoutineExecution.start_time < next_month_dt,
            )
            .all()
        )

        done_dates = {log.start_time.date() for log in habit_logs if log.start_time}
        done_days = len(done_dates)
        remaining_days = max(goal_days - done_days, 0)
        progress_rate = (done_days / goal_days) if goal_days > 0 else None

        title = habit_routine.name
        # normalize_routine_name을 이미 사용 중이면 표기용 이름 정리
        try:
            from .maping import normalize_routine_name
            display_name = normalize_routine_name(title)
        except Exception:
            display_name = title

        habit_info.update({
            "enabled": True,
            "routine_id": habit_routine.id,
            "title": title,
            "display_name": display_name,
            "goal_days": goal_days,
            "done_days": done_days,
            "remaining_days": remaining_days,
            "progress_rate": progress_rate,
        })

    return jsonify({
        "user_id": user_id,
        "year": year,
        "month": month,
        "monthly_summary": monthly_summary,
        "habit": habit_info,
    })


# === 테스트용 더미 데이터 SEED 함수 ===
def seed_demo_data(user_id: int = 1, target_date: date | None = None) -> None:
    """
    1명의 사용자(user_id)가 아침/낮/저녁 3개의 루틴을 가지고 있다고 가정하고
    Routines, RoutineExecution, WeatherInfo에 테스트 데이터를 넣는다.
    DB에는 문자열 코드(ROUTINE_TYPE, SCHEDULE_TYPE, PREFERRED_TIME, WEATHER)를 저장.
    """
    if target_date is None:
        target_date = date.today()

    # 1) 기존 데모 데이터 제거
    demo_routine_ids = [9001, 9002, 9003]

    db.session.query(RoutineExecution).filter(
        RoutineExecution.routine_id.in_(demo_routine_ids)
    ).delete(synchronize_session=False)

    db.session.query(Routine).filter(
        Routine.id.in_(demo_routine_ids)
    ).delete(synchronize_session=False)

    db.session.commit()

    # 2) 날씨 (문자열로 저장)
    weather = WeatherInfo.query.filter_by(date=target_date).first()
    if not weather:
        weather = WeatherInfo(  # type: ignore
            date=target_date,
            temperature=20.0,
            humidity=60.0,
            weather="맑음",   # 또는 "SUNNY"
            pm25=30.0,
            pm10=40.0,
        )
        db.session.add(weather)
        db.session.flush()

    base_created = datetime.combine(target_date, time(0, 0))

    # 3) Routines 3개 생성 (문자열로 저장)
    r_morning = Routine(  # type: ignore
        id=9001,
        user_id=user_id,
        name="아침 세탁기 돌리기",
        routine_type="LAUNDRY",
        serial_no="WM001",
        run_minutes=40,
        schedule_type="DAILY",
        is_active=True,
        preferred_time="07:00",
        created_at=base_created,
    )
    db.session.add(r_morning)

    r_noon = Routine(  # type: ignore
        id=9002,
        user_id=user_id,
        name="낮에 바닥 청소하기",
        routine_type="CLEANING",
        serial_no="CL001",
        run_minutes=30,
        schedule_type="DAILY",
        is_active=True,
        preferred_time="15:00",
        created_at=base_created,
    )
    db.session.add(r_noon)

    r_evening = Routine(  # type: ignore
        id=9003,
        user_id=user_id,
        name="저녁에 건조기 돌리기",
        routine_type="LAUNDRY",
        serial_no="DR001",
        run_minutes=50,
        schedule_type="DAILY",
        is_active=True,
        preferred_time="21:00",
        created_at=base_created,
    )
    db.session.add(r_evening)

    db.session.flush()

    # 4) RoutineExecution 3개 생성 (숫자는 그대로 사용)
    def _dt(h: int, m: int = 0) -> datetime:
        return datetime(
            year=target_date.year,
            month=target_date.month,
            day=target_date.day,
            hour=h,
            minute=m,
        )

    exec_morning = RoutineExecution(  # type: ignore
        id=9101,
        user_id=user_id,
        routine_id=r_morning.id,
        status=0,  # 0 = PENDING
        start_time=_dt(7, 30),
        end_time=None,
        run_time=40,
        recommended_flag=1,
        priority_score=None,
        created_at=_dt(7, 30),
    )
    db.session.add(exec_morning)

    exec_noon = RoutineExecution(  # type: ignore
        id=9102,
        user_id=user_id,
        routine_id=r_noon.id,
        status=0,
        start_time=_dt(15, 0),
        end_time=None,
        run_time=30,
        recommended_flag=1,
        priority_score=None,
        created_at=_dt(15, 0),
    )
    db.session.add(exec_noon)

    exec_evening = RoutineExecution(  # type: ignore
        id=9103,
        user_id=user_id,
        routine_id=r_evening.id,
        status=0,
        start_time=_dt(21, 0),
        end_time=None,
        run_time=50,
        recommended_flag=1,
        priority_score=None,
        created_at=_dt(21, 0),
    )
    db.session.add(exec_evening)

    db.session.commit()
    current_app.logger.info("✅ seed_demo_data 완료(user_id=%s, date=%s)", user_id, target_date)



@recommend_bp.route("/test-model", methods=["GET"])
def test_model():
    """
    XGBoost 모델이 정상 로딩되고 predict() 동작하는지 테스트.
    실제 feature_cols 구조에 맞는 샘플 데이터를 사용함.
    """
    model = current_app.model  # type: ignore
    feature_cols = current_app.feature_cols  # type: ignore

    if model is None or feature_cols is None:
        return jsonify({"error": "ML model not loaded"}), 500

    # === 실제 모델 feature에 맞춘 테스트 샘플 ===
    sample = {
        "ROUTINE_TYPE": 1,         # AFTER_WORK
        "SCHEDULE_TYPE": 1,        # DAILY
        "PREFERRED_TIME": 19,      # 7 PM
        "RUN_TIME": 30,
        "EXEC_HOUR": 20,
        "EXEC_DOW": 2,             # 화요일
        "RUN_MINUTES": 30,
        "RECOMMENDED_FLAG": 0,
        "TEMPERATURE": 18.5,
        "HUMIDITY": 55.0,
        "WEATHER": 1,
        "PM25": 28.0,
        "PM10": 40.0,
    }

    df = pd.DataFrame([sample])

    # 모델에서 요구하는 순서로 배치
    X = df[feature_cols]

    pred = float(model.predict(X)[0])

    return jsonify({
        "feature_order": feature_cols,
        "input": sample,
        "predicted_priority_score": pred
    })

@recommend_bp.route("/seed-demo", methods=["POST", "GET"])
def seed_demo_endpoint():
    """
    테스트용 더미 데이터(아침/낮/저녁 3개 루틴)를 생성하는 엔드포인트.
    예: GET /api/recommend/seed-demo?user_id=1
    """
    try:
        user_id = request.args.get("user_id", default=1, type=int)
        date_str = request.args.get("date")  # yyyy-mm-dd 형식 옵션
        if date_str:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        else:
            target_date = date.today()

        current_app.logger.info(f"🌱 seed_demo_endpoint 호출됨: user_id={user_id}, date={target_date}")
        
        seed_demo_data(user_id=user_id, target_date=target_date)

        return jsonify({
            "status": "ok",
            "message": "demo data seeded",
            "user_id": user_id,
            "date": str(target_date),
        })
    except Exception as e:
        current_app.logger.exception("seed_demo_endpoint error")
        import traceback
        return jsonify({
            "status": "error", 
            "message": str(e),
            "traceback": traceback.format_exc()
        }), 500

