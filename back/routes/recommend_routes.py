from flask import Blueprint, current_app, request, jsonify
from datetime import datetime, time, date, timedelta
import pandas as pd  # type: ignore
from sqlalchemy.exc import DatabaseError  # type: ignore
from sqlalchemy import or_, func, cast, String, case, text  # type: ignore
from Project.extensions import db
from models import User, Routine, Notification, RoutineExecution , UserDevice  ,WeatherInfo, DeviceLog
import re

from .maping import encode_routine_type, encode_schedule_type, encode_weather, REVERSE_ROUTINE_TYPE, REVERSE_SCHEDULE_TYPE, REVERSE_WEATHER, detect_routine_type_from_name
from .maping import parse_preferred_time, is_scheduled_today, is_done_today, is_failed_today, is_goal_achieved, normalize_routine_name, get_korean_object_particle
from .utils import distance_km, today_date, safe_commit, error_response


recommend_bp = Blueprint("recommend", __name__)

# =========================
# 시간대 필터링 관련 상수 및 함수
# =========================

TIME_RANGE = {
    "DAWN": (0, 5),
    "MORNING": (6, 11),
    "AFTERNOON": (12, 17),
    "EVENING": (18, 23),
    "ANY": (0, 23),
}

def is_time_match(preferred_time: str, now_hour: int) -> bool:
    """
    preferred_time과 현재 시간이 일치하는지 확인.
    
    Args:
        preferred_time: 루틴의 preferred_time (예: "MORNING", "AFTERNOON", "07:00", "15:00")
        now_hour: 현재 시간 (0-23)
    
    Returns:
        시간대가 일치하면 True, 일치하지 않으면 False
        preferred_time이 없거나 매핑되지 않으면 True (필터링하지 않음)
    """
    if not preferred_time:
        return True
    
    preferred_time_upper = preferred_time.upper().strip()
    
    # TIME_RANGE에 직접 매핑되는 경우 (예: "MORNING", "AFTERNOON")
    if preferred_time_upper in TIME_RANGE:
        start_h, end_h = TIME_RANGE[preferred_time_upper]
        return start_h <= now_hour <= end_h
    
    # 시간 형식인 경우 (예: "07:00", "15:00") - HH:MM 또는 HHMM 형식
    # 시간 부분만 추출하여 시간대 범위와 비교
    time_match = re.match(r"(\d{1,2})[:]?(\d{2})?", preferred_time)
    if time_match:
        hour_str = time_match.group(1)
        try:
            preferred_hour = int(hour_str)
            if 0 <= preferred_hour <= 23:
                # 시간대 범위에 해당하는지 확인
                if 0 <= preferred_hour <= 5:
                    # DAWN 시간대
                    return TIME_RANGE["DAWN"][0] <= now_hour <= TIME_RANGE["DAWN"][1]
                elif 6 <= preferred_hour <= 11:
                    # MORNING 시간대
                    return TIME_RANGE["MORNING"][0] <= now_hour <= TIME_RANGE["MORNING"][1]
                elif 12 <= preferred_hour <= 17:
                    # AFTERNOON 시간대
                    return TIME_RANGE["AFTERNOON"][0] <= now_hour <= TIME_RANGE["AFTERNOON"][1]
                elif 18 <= preferred_hour <= 23:
                    # EVENING 시간대
                    return TIME_RANGE["EVENING"][0] <= now_hour <= TIME_RANGE["EVENING"][1]
        except ValueError:
            pass
    
    # 매핑되지 않은 경우 필터링하지 않음 (기본적으로 포함)
    return True


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
    now_hour = now.hour
    for r in all_routines:
        if not is_scheduled_today(r, today):
            continue
        if is_done_today(r, user_id, today):
            continue
        # 추천에서는 실패한 루틴 제외
        if is_failed_today(r, user_id, today):
            continue
        # 시간대 필터링: 현재 시간과 맞지 않는 루틴은 제외
        if not is_time_match(r.preferred_time, now_hour):
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
    # 성능 최적화: 모든 루틴의 마지막 실행 기록을 한 번의 쿼리로 조회 (N+1 쿼리 문제 해결)
    routine_ids = [r.id for r in routines]
    last_logs_query = (
        db.session.query(
            RoutineExecution.routine_id,
            RoutineExecution.run_time,
            RoutineExecution.recommended_flag,
            func.row_number()
            .over(
                partition_by=RoutineExecution.routine_id,
                order_by=RoutineExecution.start_time.desc()
            )
            .label('rn')
        )
        .filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.routine_id.in_(routine_ids)
        )
        .subquery()
    )
    
    # 각 루틴별로 가장 최근 실행 기록만 가져오기
    last_logs_map = {}
    if routine_ids:
        last_logs = (
            db.session.query(last_logs_query)
            .filter(last_logs_query.c.rn == 1)
            .all()
        )
        for log in last_logs:
            last_logs_map[log.routine_id] = {
                'run_time': log.run_time,
                'recommended_flag': log.recommended_flag
            }
    
    rows = []
    for r in routines:
        rt = encode_routine_type(r.routine_type)
        st = encode_schedule_type(r.schedule_type)
        preferred_hour = parse_preferred_time(r.preferred_time)

        last_log = last_logs_map.get(r.id)
        if last_log:
            run_time = int(last_log['run_time'] or r.run_minutes or 30)
            recommended_flag = int(bool(last_log['recommended_flag']))
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
    )

    TOP_K = 3
    top_df = df_sorted.head(TOP_K)

    recommendations = []
    for _, row in df_sorted.iterrows():
        rt_code = int(row["ROUTINE_TYPE"])
        st_code = int(row["SCHEDULE_TYPE"])

        recommendations.append({
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
    now_hour = now.hour
    for r in all_routines:
        if not is_scheduled_today(r, today):
            continue
        if is_done_today(r, user_id, today):
            continue
        # 추천에서는 실패한 루틴 제외
        if is_failed_today(r, user_id, today):
            continue
        # 시간대 필터링: 현재 시간과 맞지 않는 루틴은 제외
        if not is_time_match(r.preferred_time, now_hour):
            continue
        routines.append(r)

    if not routines:
        return jsonify([])  # 오늘 추천할 루틴 없음


    # 날씨 가져오기 (없으면 default)
    # 디버깅: 모든 날씨 정보 조회해서 로그 출력
    all_weather = WeatherInfo.query.all()
    current_app.logger.info(f"🔍 [Priority API] DB에 저장된 모든 날씨 정보:")
    for w in all_weather:
        current_app.logger.info(f"  - id={w.id}, date={w.date} (type={type(w.date).__name__}), weather={w.weather}")
    
    current_app.logger.info(f"🔍 [Priority API] 조회하려는 날짜: {today} (type={type(today).__name__})")
    
    weather = WeatherInfo.query.filter_by(date=today).first()
    
    # 날씨 정보가 없으면 기본값으로 "맑음" 사용
    if not weather:
        temp = 20.0
        humi = 60.0
        weather_code = 0
        pm25 = 40.0
        pm10 = 60.0
        current_app.logger.warning(f"⚠️ [Priority API] 날씨 정보 없음: date={today}, 기본값 사용 (weather_code=0: 맑음)")
    else:
        temp = float(weather.temperature) if weather.temperature else 20.0
        humi = float(weather.humidity) if weather.humidity else 60.0
        weather_code = encode_weather(weather.weather) if weather.weather is not None else 0
        pm25 = float(weather.pm25) if weather.pm25 else 40.0
        pm10 = float(weather.pm10) if weather.pm10 else 60.0
        current_app.logger.info(f"✅ [Priority API] 날씨 정보 로드 성공: date={today}, weather={weather.weather}, weather_code={weather_code}")

    # 성능 최적화: 모든 루틴의 마지막 실행 기록을 한 번의 쿼리로 조회 (N+1 쿼리 문제 해결)
    routine_ids = [r.id for r in routines]
    last_logs_query = (
        db.session.query(
            RoutineExecution.routine_id,
            RoutineExecution.run_time,
            RoutineExecution.recommended_flag,
            func.row_number()
            .over(
                partition_by=RoutineExecution.routine_id,
                order_by=RoutineExecution.start_time.desc()
            )
            .label('rn')
        )
        .filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.routine_id.in_(routine_ids)
        )
        .subquery()
    )
    
    # 각 루틴별로 가장 최근 실행 기록만 가져오기
    last_logs_map = {}
    if routine_ids:
        last_logs = (
            db.session.query(last_logs_query)
            .filter(last_logs_query.c.rn == 1)
            .all()
        )
        for log in last_logs:
            last_logs_map[log.routine_id] = {
                'run_time': log.run_time,
                'recommended_flag': log.recommended_flag
            }
    
    rows = []
    for r in routines:
        # ROUTINE_TYPE (문자열/숫자 → 숫자)
        rt = encode_routine_type(r.routine_type)

        # SCHEDULE_TYPE (문자열/숫자 → 숫자)
        st = encode_schedule_type(r.schedule_type)

        # PREFERRED_TIME (문자열/숫자 → 시 단위 정수)
        preferred_hour = parse_preferred_time(r.preferred_time)

        # 최근 실행 기록 (배치 조회된 데이터 사용)
        last_log = last_logs_map.get(r.id)
        if last_log:
            run_time = int(last_log['run_time'] or r.run_minutes or 30)
            recommended_flag = int(bool(last_log['recommended_flag']))
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

@recommend_bp.route("/priority/selected", methods=["POST"])
def get_priority_for_selected_routines():
    """
    선택된 루틴들의 우선순위 점수를 계산하는 API
    POST /api/recommend/priority/selected
    Body: {
        "user_id": 1,
        "routine_ids": [9001, 9002, 9003],
        "date": "2025-12-12"  # optional, 오늘 날짜 사용
    }
    """
    model = current_app.model  # type: ignore
    feature_cols = current_app.feature_cols  # type: ignore

    if model is None or feature_cols is None:
        return jsonify({"error": "ML model not loaded"}), 500

    data = request.get_json() or {}
    user_id = data.get("user_id", 1)
    routine_ids = data.get("routine_ids", [])
    date_str = data.get("date")

    if not routine_ids:
        return jsonify({"error": "routine_ids required"}), 400

    try:
        user = User.query.get(user_id)
    except DatabaseError as e:
        error_msg = str(e.orig) if hasattr(e, 'orig') else str(e)
        return jsonify({
            "error": "Database connection failed",
            "message": "Unable to connect to the database.",
            "details": error_msg,
        }), 503
    
    if not user:
        return jsonify({"error": "user not found"}), 404

    # 날짜 파싱
    if date_str:
        try:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            return jsonify({"error": "Invalid date format. Use YYYY-MM-DD"}), 400
    else:
        target_date = date.today()

    now = datetime.now()
    exec_hour = now.hour
    exec_dow = now.weekday()

    # 선택된 루틴들 조회
    try:
        routines = Routine.query.filter(
            Routine.id.in_(routine_ids),
            Routine.user_id == user_id,
            Routine.is_active == True
        ).all()
    except DatabaseError as e:
        error_msg = str(e.orig) if hasattr(e, 'orig') else str(e)
        return jsonify({
            "error": "Database query failed",
            "message": "Unable to query routines from the database.",
            "details": error_msg
        }), 503

    if not routines:
        return jsonify([])

    # 날씨 가져오기
    weather = WeatherInfo.query.filter_by(date=target_date).first()
    temp = float(weather.temperature) if weather and weather.temperature else 20.0
    humi = float(weather.humidity) if weather and weather.humidity else 60.0
    weather_code = encode_weather(weather.weather) if weather and weather.weather is not None else 0
    pm25 = float(weather.pm25) if weather and weather.pm25 else 40.0
    pm10 = float(weather.pm10) if weather and weather.pm10 else 60.0

    # 성능 최적화: 모든 루틴의 마지막 실행 기록을 한 번의 쿼리로 조회 (N+1 쿼리 문제 해결)
    routine_ids_list = [r.id for r in routines]
    last_logs_query = (
        db.session.query(
            RoutineExecution.routine_id,
            RoutineExecution.run_time,
            RoutineExecution.recommended_flag,
            func.row_number()
            .over(
                partition_by=RoutineExecution.routine_id,
                order_by=RoutineExecution.start_time.desc()
            )
            .label('rn')
        )
        .filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.routine_id.in_(routine_ids_list)
        )
        .subquery()
    )
    
    # 각 루틴별로 가장 최근 실행 기록만 가져오기
    last_logs_map = {}
    if routine_ids_list:
        last_logs = (
            db.session.query(last_logs_query)
            .filter(last_logs_query.c.rn == 1)
            .all()
        )
        for log in last_logs:
            last_logs_map[log.routine_id] = {
                'run_time': log.run_time,
                'recommended_flag': log.recommended_flag
            }
    
    rows = []
    for r in routines:
        rt = encode_routine_type(r.routine_type)
        st = encode_schedule_type(r.schedule_type)
        preferred_hour = parse_preferred_time(r.preferred_time)

        # 최근 실행 기록 (배치 조회된 데이터 사용)
        last_log = last_logs_map.get(r.id)
        if last_log:
            run_time = int(last_log['run_time'] or r.run_minutes or 30)
            recommended_flag = int(bool(last_log['recommended_flag']))
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

    # feature 순서 맞추기
    missing = [c for c in feature_cols if c not in df.columns]
    if missing:
        return jsonify({"error": "missing features", "missing": missing}), 500

    X = df[feature_cols]
    preds = model.predict(X)
    df["pred_priority_score"] = preds

    # routine_ids 순서 유지하면서 점수 추가
    # MONTHLY 루틴은 우선순위에서 제외하거나 맨 뒤로 보냄
    result = []
    monthly_routines = []
    routine_id_to_score = dict(zip(df["ROUTINE_ID"], df["pred_priority_score"]))
    
    for routine_id in routine_ids:
        if routine_id in routine_id_to_score:
            routine = next((r for r in routines if r.id == routine_id), None)
            if routine:
                score_data = {
                    "routine_id": int(routine_id),
                    "routine_name": routine.name,
                    "pred_priority_score": float(routine_id_to_score[routine_id]),
                }
                # MONTHLY 루틴은 별도로 분리
                if (routine.schedule_type or "").upper() == "MONTHLY":
                    monthly_routines.append(score_data)
                else:
                    result.append(score_data)
    
    # MONTHLY 루틴을 맨 뒤에 추가 (점수 기준 정렬)
    monthly_routines.sort(key=lambda x: x["pred_priority_score"], reverse=True)
    result.extend(monthly_routines)

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

    # routine_type이 없으면 루틴 이름에서 자동 감지
    if not routine_type:
        routine_type = detect_routine_type_from_name(name)
        current_app.logger.info(f"[CreateRoutine] routine_type 자동 감지: '{name}' -> '{routine_type}'")

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

    routine = Routine(
        user_id=user_id,
        name=name,
        routine_type=routine_type,
        schedule_type=schedule_type,
        schedule_frequency=schedule_frequency,
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
            "schedule_frequency": r.schedule_frequency,
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

    # name이 변경되면 routine_type도 자동으로 업데이트 (routine_type이 명시적으로 제공되지 않은 경우)
    if "name" in data:
        new_name = data["name"]
        setattr(routine, "name", new_name)
        # routine_type이 명시적으로 제공되지 않았으면 자동 감지
        if "routine_type" not in data:
            detected_type = detect_routine_type_from_name(new_name)
            routine.routine_type = detected_type
            current_app.logger.info(f"[UpdateRoutine] routine_type 자동 감지: '{new_name}' -> '{detected_type}'")
    
    for field in ["routine_type", "schedule_type",
                  "preferred_time", "run_minutes", "serial_no"]:
        if field in data:
            setattr(routine, field, data[field])

    if "is_active" in data:
        routine.is_active = 1 if data["is_active"] else 0

    # 습관 목표 일수 업데이트
    if "habit_goal_days" in data:
        habit_goal_days = data["habit_goal_days"]
        if habit_goal_days is None:
            routine.habit_goal_days = None
        else:
            try:
                routine.habit_goal_days = int(habit_goal_days)
            except (ValueError, TypeError):
                return jsonify({"error": "habit_goal_days must be an integer"}), 400

    # 습관 시작 날짜 업데이트
    if "habit_start_date" in data:
        habit_start_date = data["habit_start_date"]
        if habit_start_date is None:
            routine.habit_start_date = None
        else:
            try:
                # 문자열인 경우 파싱 (예: "2025-12-01" 또는 "2025-12-01T00:00:00")
                if isinstance(habit_start_date, str):
                    from datetime import datetime as dt
                    # ISO 형식 또는 YYYY-MM-DD 형식 파싱
                    if "T" in habit_start_date:
                        routine.habit_start_date = dt.fromisoformat(habit_start_date.replace("Z", "+00:00")).date()
                    else:
                        routine.habit_start_date = dt.strptime(habit_start_date, "%Y-%m-%d").date()
                else:
                    # 이미 date 객체인 경우
                    routine.habit_start_date = habit_start_date
            except (ValueError, TypeError) as e:
                return jsonify({"error": f"invalid habit_start_date format: {e}"}), 400

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

    # status는 숫자로 저장됨 (DB는 NUMBER(2,0))
    # 0=pending, 1=running, 2=done(완료), 3=failed(실패)
    status_int = int(status) if isinstance(status, (int, float, str)) and str(status).isdigit() else 2
    
    exec_log = RoutineExecution(
        user_id=user_id,
        routine_id=routine_id,
        status=status_int,
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
    특정 날짜의 루틴 리스트 API
    GET /api/recommend/today-routines?user_id=1&date=2025-12-12
    date 파라미터가 없으면 오늘 날짜 사용
    """
    user_id = request.args.get("user_id", type=int)
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    # 날짜 파라미터 처리
    date_str = request.args.get("date")
    if date_str:
        try:
            today = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            return jsonify({"error": "Invalid date format. Use YYYY-MM-DD"}), 400
    else:
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
        # 1) 오늘 스케줄인지 검사 (created_at 기준)
        if not is_scheduled_today(r, today):
            continue

        # 2) WEEKLY/MONTHLY 루틴의 목표 달성 여부 확인
        # 목표 달성 시 더 이상 표시하지 않음 (DAILY는 제외)
        st = (r.schedule_type or "").upper()
        if st != "DAILY" and is_goal_achieved(r, user_id, today):
            continue

        # 3) 오늘 완료 / 실패 여부 체크
        # DAILY 루틴은 체크되어도 계속 표시 (필터링하지 않음)
        last_log = (
            RoutineExecution.query
            .filter_by(user_id=user_id, routine_id=r.id)
            .order_by(RoutineExecution.start_time.desc())
            .first()
        )

        done = False
        failed = False
        if last_log and last_log.start_time and last_log.start_time.date() == today:
            # status는 숫자로 저장됨: 2=완료, 3=실패
            if last_log.status == 2:
                done = True
            elif last_log.status == 3:
                failed = True
        
        # DAILY 루틴은 완료되어도 필터링하지 않음 (계속 표시)
        # WEEKLY/MONTHLY 루틴은 완료되면 목표 달성으로 간주하여 이미 필터링됨

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
            "failed": failed,
        })


    # 2) 정렬: preferred_time 기준
    today_list.sort(key=lambda x: x["preferred_hour"])

    return jsonify(today_list)

@recommend_bp.route("/weather", methods=["GET"])
def get_weather():
    """오늘의 날씨 정보 반환
    GET /api/recommend/weather?user_id=1&date=2025-01-15 (옵션: date 없으면 오늘)
    """
    user_id = request.args.get("user_id", type=int, default=1)
    date_str = request.args.get("date")
    if date_str:
        try:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            return jsonify({"error": "Invalid date format. Use YYYY-MM-DD"}), 400
    else:
        target_date = today_date()
    
    # 디버깅: 모든 날씨 정보 조회해서 로그 출력
    all_weather = WeatherInfo.query.all()
    current_app.logger.info(f"🔍 [Weather API] DB에 저장된 모든 날씨 정보 (총 {len(all_weather)}개):")
    for w in all_weather:
        date_str = w.date.isoformat() if w.date else "None"
        target_str = target_date.isoformat()
        is_match = date_str == target_str
        current_app.logger.info(f"  - id={w.id}, date={date_str} (type={type(w.date).__name__}), weather={w.weather}, matches={is_match}")
    
    current_app.logger.info(f"🔍 [Weather API] 조회하려는 날짜: {target_date.isoformat()} (type={type(target_date).__name__})")
    
    # 날짜 비교를 명시적으로 수행
    weather = None
    for w in all_weather:
        if w.date and w.date == target_date:
            weather = w
            current_app.logger.info(f"✅ [Weather API] 날짜 매칭 성공: {w.date.isoformat()} == {target_date.isoformat()}")
            break
    
    if not weather:
        # SQLAlchemy 쿼리로도 한 번 더 시도
        weather = WeatherInfo.query.filter_by(date=target_date).first()
        if weather:
            current_app.logger.info(f"✅ [Weather API] SQLAlchemy 쿼리로 날씨 정보 조회 성공")
        else:
            current_app.logger.warning(f"⚠️ [Weather API] 날씨 정보 없음: date={target_date.isoformat()}, 기본값 사용 (weather_code=0: 맑음)")
    
    # 날씨 정보가 없으면 기본값으로 "맑음" 사용
    if not weather:
        weather_code = 0  # 맑음
        weather_label = "맑음"
        temp = 20.0
        humi = 60.0
        pm25 = 40.0  # 기본값 사용 (XGBoost 모델에 숫자형 필요)
        pm10 = 60.0  # 기본값 사용 (XGBoost 모델에 숫자형 필요)
    else:
        current_app.logger.info(f"✅ [Weather API] 날씨 정보 조회 성공: date={weather.date.isoformat() if weather.date else 'None'}, weather={weather.weather}, weather_type={type(weather.weather)}")
        weather_code = encode_weather(weather.weather) if weather.weather else 0
        weather_label = REVERSE_WEATHER.get(weather_code, "맑음")
        temp = float(weather.temperature) if weather.temperature else 20.0
        humi = float(weather.humidity) if weather.humidity else 60.0
        # PM25와 PM10을 숫자형으로 변환 (None이면 기본값 사용)
        try:
            pm25 = float(weather.pm25) if weather.pm25 is not None else 40.0
        except (ValueError, TypeError):
            pm25 = 40.0
        try:
            pm10 = float(weather.pm10) if weather.pm10 is not None else 60.0
        except (ValueError, TypeError):
            pm10 = 60.0
        current_app.logger.info(f"✅ [Weather API] 날씨 코드 변환: weather='{weather.weather}' (repr: {repr(weather.weather)}) -> weather_code={weather_code}, weather_label='{weather_label}'")
        
        # 날씨 코드가 0(맑음)인데 원본이 "비"인 경우 경고
        if weather_code == 0 and weather.weather and ('비' in str(weather.weather) or 'rain' in str(weather.weather).lower()):
            current_app.logger.error(f"❌ [Weather API] 날씨 인코딩 오류! 원본='{weather.weather}'인데 weather_code=0(맑음)으로 변환됨!")
    
    # 사용자의 활성 루틴 조회 (날씨에 따라 추천할 루틴 찾기)
    try:
        user_routines = Routine.query.filter_by(
            user_id=user_id,
            is_active=True
        ).all()
    except Exception as e:
        current_app.logger.warning(f"Failed to query routines for user {user_id}: {e}")
        user_routines = []
    
    # 날씨 기반 추천 메시지 생성 (우선순위 점수 기반)
    # 모든 활성 루틴에 대해 우선순위 점수를 계산하여 가장 높은 점수의 루틴 추천
    recommendation_messages = []
    
    # 모든 활성 루틴을 후보로 사용 (날씨 조건으로 필터링하지 않음)
    candidate_routines = user_routines
    current_app.logger.info(f"🔍 [Weather API] 후보 루틴 수: {len(candidate_routines)}")
    if candidate_routines:
        current_app.logger.info(f"🔍 [Weather API] 후보 루틴 목록: {[r.name for r in candidate_routines]}")
    
    # 후보 루틴이 있으면 우선순위 점수 계산하여 가장 높은 점수의 루틴 추천
    if candidate_routines:
        try:
            # ML 모델이 로드되어 있는지 확인
            model = current_app.model  # type: ignore
            feature_cols = current_app.feature_cols  # type: ignore
            
            current_app.logger.info(f"🔍 [Weather API] ML 모델 상태: model={'있음' if model is not None else '없음'}, feature_cols={'있음' if feature_cols is not None else '없음'}")
            
            if model is not None and feature_cols is not None:
                # 우선순위 점수 계산
                now = datetime.now()
                exec_hour = now.hour
                exec_dow = now.weekday()
                
                # 최근 실행 기록 조회
                routine_ids_list = [r.id for r in candidate_routines]
                last_logs_query = (
                    db.session.query(
                        RoutineExecution.routine_id,
                        RoutineExecution.run_time,
                        RoutineExecution.recommended_flag,
                        func.row_number()
                        .over(
                            partition_by=RoutineExecution.routine_id,
                            order_by=RoutineExecution.start_time.desc()
                        )
                        .label('rn')
                    )
                    .filter(
                        RoutineExecution.user_id == user_id,
                        RoutineExecution.routine_id.in_(routine_ids_list)
                    )
                    .subquery()
                )
                
                last_logs_map = {}
                if routine_ids_list:
                    last_logs = (
                        db.session.query(last_logs_query)
                        .filter(last_logs_query.c.rn == 1)
                        .all()
                    )
                    for log in last_logs:
                        last_logs_map[log.routine_id] = {
                            'run_time': log.run_time,
                            'recommended_flag': log.recommended_flag
                        }
                
                # 우선순위 점수 계산을 위한 데이터 준비
                rows = []
                for r in candidate_routines:
                    rt = encode_routine_type(r.routine_type)
                    st = encode_schedule_type(r.schedule_type)
                    preferred_hour = parse_preferred_time(r.preferred_time)
                    
                    last_log = last_logs_map.get(r.id)
                    if last_log:
                        run_time = int(last_log['run_time'] or r.run_minutes or 30)
                        recommended_flag = int(bool(last_log['recommended_flag']))
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
                
                # 우선순위 점수 계산
                df = pd.DataFrame(rows)
                missing = [c for c in feature_cols if c not in df.columns]
                if not missing:
                    X = df[feature_cols]
                    preds = model.predict(X)
                    df["pred_priority_score"] = preds
                    
                    # 가장 높은 점수의 루틴 선택
                    best_routine = df.loc[df["pred_priority_score"].idxmax()]
                    best_routine_name = best_routine["ROUTINE_NAME"]
                    best_routine_score = best_routine["pred_priority_score"]
                    particle = get_korean_object_particle(best_routine_name)
                    
                    # 디버깅: 모든 루틴의 점수 로그 출력
                    current_app.logger.info(f"🔍 [Weather API] 우선순위 점수 계산 결과 (총 {len(df)}개 루틴):")
                    for idx, row in df.iterrows():
                        current_app.logger.info(f"  - {row['ROUTINE_NAME']}: {row['pred_priority_score']:.4f}")
                    current_app.logger.info(f"✅ [Weather API] 선택된 루틴: {best_routine_name} (점수: {best_routine_score:.4f})")
                    
                    # 추천 이유 설명 추가
                    if weather_code == 2:  # 비
                        recommendation_messages.append(f"비가와서 {best_routine_name}{particle} 추천드려요.")
                        recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
                    elif weather_code == 3:  # 눈
                        recommendation_messages.append(f"눈이와서 {best_routine_name}{particle} 추천드려요.")
                        recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
                    elif weather_code == 1:  # 흐림
                        recommendation_messages.append(f"흐려서 {best_routine_name}{particle} 추천드려요.")
                        recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
                    else:  # 맑음
                        recommendation_messages.append(f"맑아서 {best_routine_name}{particle} 하기에 좋은 날이에요.")
                        recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
                else:
                    # ML 모델 feature가 없으면 첫 번째 루틴 사용
                    best_routine = candidate_routines[0]
                    particle = get_korean_object_particle(best_routine.name)
                    
                    # 추천 이유 설명 추가
                    if weather_code == 2:  # 비
                        recommendation_messages.append(f"비가와서 {best_routine.name}{particle} 추천드려요.")
                        recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
                    elif weather_code == 3:  # 눈
                        recommendation_messages.append(f"눈이와서 {best_routine.name}{particle} 추천드려요.")
                        recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
                    elif weather_code == 1:  # 흐림
                        recommendation_messages.append(f"흐려서 {best_routine.name}{particle} 추천드려요.")
                        recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
                    else:  # 맑음
                        recommendation_messages.append(f"맑아서 {best_routine.name}{particle} 하기에 좋은 날이에요.")
                        recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
            else:
                # ML 모델이 없으면 첫 번째 루틴 사용
                best_routine = candidate_routines[0]
                particle = get_korean_object_particle(best_routine.name)
                
                # 추천 이유 설명 추가
                if weather_code == 2:  # 비
                    recommendation_messages.append(f"비가 예정된 오늘, {best_routine.name}{particle} 추천드려요.")
                    recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
                elif weather_code == 3:  # 눈
                    recommendation_messages.append(f"{best_routine.name}{particle} 하기에 좋은 날씨예요.")
                    recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
                elif weather_code == 1:  # 흐림
                    recommendation_messages.append(f"{best_routine.name}{particle} 하기에 좋은 날씨예요.")
                    recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
                else:  # 맑음
                    recommendation_messages.append(f"맑은 날씨예요. {best_routine.name}{particle} 하기에 좋은 날이에요.")
                    recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
        except Exception as e:
            current_app.logger.error(f"❌ [Weather API] 우선순위 점수 계산 실패: {e}")
            # 에러 발생 시 첫 번째 루틴 사용
            best_routine = candidate_routines[0]
            particle = get_korean_object_particle(best_routine.name)
            
            # 추천 이유 설명 추가
            if weather_code == 2:  # 비
                recommendation_messages.append(f"비가와서 {best_routine.name}{particle} 추천드려요.")
                recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
            elif weather_code == 3:  # 눈
                recommendation_messages.append(f"눈이와서 {best_routine.name}{particle} 추천드려요.")
                recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
            elif weather_code == 1:  # 흐림
                recommendation_messages.append(f"흐려서 {best_routine.name}{particle} 추천드려요.")
                recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
            else:  # 맑음
                recommendation_messages.append(f"맑아서 {best_routine.name}{particle} 하기에 좋은 날이에요.")
                recommendation_messages.append("날씨, 온도, 습도, 시간 등 요소를 고려했어요.")
    
    # 미세먼지 수치 확인 (pm25: 35 이상, pm10: 75 이상이면 나쁨)
    if pm25 is not None and pm25 >= 35:
        recommendation_messages.append("미세먼지 수치가 높아요. 외출 시 주의하세요.")
    elif pm10 is not None and pm10 >= 75:
        recommendation_messages.append("미세먼지 수치가 높아요. 외출 시 주의하세요.")
    
    # 메시지들을 줄바꿈으로 연결
    recommendation_message = "\n".join(recommendation_messages) if recommendation_messages else None
    
    response_data = {
        "date": target_date.isoformat(),
        "weather": weather.weather if weather else "맑음",
        "weather_code": weather_code,
        "weather_label": weather_label,
        "temperature": float(weather.temperature) if weather and weather.temperature else None,
        "humidity": float(weather.humidity) if weather and weather.humidity else None,
        "pm25": pm25,
        "pm10": pm10,
        "recommendation_message": recommendation_message,
    }
    current_app.logger.info(f"✅ [Weather API] 최종 응답 데이터: {response_data}")
    return jsonify(response_data), 200


@recommend_bp.route("/unused-notification", methods=["GET"])
def get_unused_notification():
    """
    미사용 루틴 알림 정보 반환
    GET /api/recommend/unused-notification?user_id=1
    """
    user_id = request.args.get("user_id", type=int, default=1)
    
    try:
        user = User.query.get(user_id)
    except DatabaseError as e:
        error_msg = str(e.orig) if hasattr(e, 'orig') else str(e)
        return jsonify({
            "error": "Database connection failed",
            "message": "Unable to connect to the database.",
            "details": error_msg,
        }), 503
    
    if not user:
        return jsonify({"error": "user not found"}), 404
    
    # 현재 날짜 기준으로 이번 달 계산
    now = datetime.now()
    current_month_start = date(now.year, now.month, 1)
    if now.month < 12:
        current_month_end = date(now.year, now.month + 1, 1) - timedelta(days=1)
    else:
        current_month_end = date(now.year + 1, 1, 1) - timedelta(days=1)
    
    # 디버깅: 날짜 범위 확인
    current_app.logger.info(f"🔍 [UnusedNotification] 현재 시간: {now}")
    current_app.logger.info(f"🔍 [UnusedNotification] 이번 달 시작: {current_month_start}")
    current_app.logger.info(f"🔍 [UnusedNotification] 이번 달 종료: {current_month_end}")
    
    # 활성화된 루틴 중에서 주기적으로 실행해야 하는 루틴 찾기 (WEEKLY, MONTHLY 등)
    routines = Routine.query.filter_by(
        user_id=user_id,
        is_active=True
    ).filter(
        Routine.schedule_type.in_(['WEEKLY', 'MONTHLY'])
    ).all()
    
    notifications = []
    
    for routine in routines:
        # 이번 달 실행 횟수 계산 (status는 숫자로 저장됨: 2=완료)
        # 디버깅: 실제 쿼리 조건 확인
        current_app.logger.info(f"🔍 [UnusedNotification] 루틴 ID={routine.id}, 이름={routine.name}")
        current_app.logger.info(f"🔍 [UnusedNotification] 날짜 범위: {current_month_start} ~ {current_month_end}")
        
        # 이번 달 범위의 실행 기록만 확인
        month_start_dt = datetime.combine(current_month_start, time.min)
        month_end_dt = datetime.combine(current_month_end, time.max)
        
        current_app.logger.info(f"🔍 [UnusedNotification] 쿼리 조건:")
        current_app.logger.info(f"  - user_id={user_id}")
        current_app.logger.info(f"  - routine_id={routine.id}")
        current_app.logger.info(f"  - status=2")
        current_app.logger.info(f"  - start_time >= {month_start_dt}")
        current_app.logger.info(f"  - start_time <= {month_end_dt}")
        
        # SQLAlchemy 세션 새로고침 (캐시 무효화)
        db.session.expire_all()
        
        # 인덱스를 활용한 COUNT 쿼리 (성능 최적화 및 정확성 보장)
        # idx_exec_goal 인덱스 (user_id, routine_id, start_time, status) 활용
        executions_this_month = RoutineExecution.query.filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.routine_id == routine.id,
            RoutineExecution.status == 2,
            RoutineExecution.start_time >= month_start_dt,
            RoutineExecution.start_time <= month_end_dt
        ).count()
        
        current_app.logger.info(f"🔍 [UnusedNotification] 이번 달 실행 횟수 (인덱스 기반 COUNT): {executions_this_month}")
        
        # 디버깅용: 실제 레코드도 확인 (인덱스와 일치하는지 검증)
        if executions_this_month > 0:
            matching_executions = RoutineExecution.query.filter(
                RoutineExecution.user_id == user_id,
                RoutineExecution.routine_id == routine.id,
                RoutineExecution.status == 2,
                RoutineExecution.start_time >= month_start_dt,
                RoutineExecution.start_time <= month_end_dt
            ).all()
            current_app.logger.info(f"🔍 [UnusedNotification] 매칭된 실행 기록 수: {len(matching_executions)}")
            for exec in matching_executions:
                current_app.logger.info(f"  - 매칭된 기록: id={exec.id}, status={exec.status}, start_time={exec.start_time}")
        
        # 예상 실행 횟수 계산 (schedule_frequency 고려)
        expected_count = 0
        
        # DB에서 직접 schedule_frequency 값을 확인 (SQLAlchemy 캐시 문제 방지)
        try:
            raw_result = db.session.execute(
                text("SELECT SCHEDULE_FREQUENCY FROM ROUTINES WHERE ID = :routine_id"),
                {"routine_id": routine.id}
            ).fetchone()
            db_schedule_frequency = raw_result[0] if raw_result else None
            current_app.logger.info(f"🔍 [UnusedNotification] DB에서 직접 읽은 schedule_frequency: {db_schedule_frequency} (타입: {type(db_schedule_frequency)})")
        except Exception as e:
            current_app.logger.error(f"❌ [UnusedNotification] DB 직접 조회 실패: {e}")
            db_schedule_frequency = None
        
        # schedule_frequency가 None이거나 0이면 기본값 1, 그 외에는 실제 값 사용
        # DB에서 직접 읽은 값을 우선 사용, 없으면 ORM 객체의 값 사용
        if db_schedule_frequency is not None and db_schedule_frequency > 0:
            schedule_frequency = int(db_schedule_frequency)
        elif routine.schedule_frequency is not None and routine.schedule_frequency > 0:
            schedule_frequency = routine.schedule_frequency
        else:
            schedule_frequency = 1
        
        # 디버깅: schedule_frequency 확인 (더 자세한 정보)
        current_app.logger.info(f"🔍 [UnusedNotification] 루틴 ID={routine.id}, 이름={routine.name}")
        current_app.logger.info(f"🔍 [UnusedNotification] schedule_type={routine.schedule_type}")
        current_app.logger.info(f"🔍 [UnusedNotification] ORM 객체의 schedule_frequency={routine.schedule_frequency} (타입: {type(routine.schedule_frequency)})")
        current_app.logger.info(f"🔍 [UnusedNotification] DB에서 직접 읽은 schedule_frequency={db_schedule_frequency}")
        current_app.logger.info(f"🔍 [UnusedNotification] 최종 계산된 schedule_frequency={schedule_frequency}")
        
        # 실행 횟수와 메시지 계산
        executions_count = 0
        time_period = ""
        if routine.schedule_type == 'WEEKLY':
            # 주 N회이면 이번 주 실행 횟수 계산
            # 이번 주의 시작일 (월요일)과 종료일 (일요일) 계산
            today = now.date()
            days_since_monday = today.weekday() - 1  # 월요일이 0
            week_start = today - timedelta(days=days_since_monday)
            week_end = week_start + timedelta(days=6)
            
            week_start_dt = datetime.combine(week_start, time.min)
            week_end_dt = datetime.combine(week_end, time.max)
            
            # 이번 주 실행 횟수 계산
            executions_count = RoutineExecution.query.filter(
                RoutineExecution.user_id == user_id,
                RoutineExecution.routine_id == routine.id,
                RoutineExecution.status == 2,
                RoutineExecution.start_time >= week_start_dt,
                RoutineExecution.start_time <= week_end_dt
            ).count()
            
            expected_count = schedule_frequency  # 주당 횟수
            time_period = "이번 주에"
            # 디버깅: 주 단위 계산 결과 확인
            current_app.logger.info(f"🔍 [UnusedNotification] WEEKLY 루틴 - 이번 주 범위: {week_start} ~ {week_end}, executions_count={executions_count}, expected_count={expected_count}")
        elif routine.schedule_type == 'MONTHLY':
            # 월 N회이면 이번 달 실행 횟수 계산
            executions_count = executions_this_month
            expected_count = schedule_frequency
            time_period = "이번달에"
        elif routine.schedule_type == 'DAILY':
            # 일 N회이면 이번 달 실행 횟수 계산
            executions_count = executions_this_month
            days_in_month = (current_month_end - current_month_start).days + 1
            expected_count = days_in_month * schedule_frequency
            time_period = "이번달에"
        else:
            # 기타 타입은 기본값
            executions_count = executions_this_month
            expected_count = schedule_frequency
            time_period = "이번달에"
        
        # 실행 횟수가 부족한 경우 알림 생성
        if executions_count < expected_count:
            remaining = expected_count - executions_count
            routine_name = normalize_routine_name(routine.name)
            
            # 루틴 타입에 따라 메시지 생성
            if '세탁기' in routine_name or 'washing' in routine_name.lower() or '세탁' in routine_name:
                particle = get_korean_object_particle(routine_name)
                first_line = f"{time_period} {routine_name}{particle} {executions_count}번 돌렸어요."
                second_line = f"{remaining}번 더 돌리셔야해요. 지금 돌리실건가요?"
            else:
                particle = get_korean_object_particle(routine_name)
                first_line = f"{time_period} {routine_name}{particle} {executions_count}번 하셨어요."
                second_line = f"{remaining}번 더 하셔야해요. 지금 하실건가요?"
            
            notifications.append({
                "routine_id": routine.id,
                "routine_name": routine_name,
                "executions_this_month": executions_this_month,
                "expected_count": expected_count,
                "remaining": remaining,
                "first_line": first_line,
                "second_line": second_line,
            })
    
    # 우선순위 점수 계산하여 가장 적절한 루틴 선택
    if notifications:
        # ML 모델이 로드되어 있는지 확인
        model = current_app.model  # type: ignore
        feature_cols = current_app.feature_cols  # type: ignore
        
        if model is not None and feature_cols is not None:
            # 우선순위 점수 계산을 위한 데이터 준비
            now = datetime.now()
            exec_hour = now.hour
            exec_dow = now.weekday()
            
            # 날씨 정보 가져오기
            today = now.date()
            weather = WeatherInfo.query.filter_by(date=today).first()
            temp = float(weather.temperature) if weather and weather.temperature else 20.0
            humi = float(weather.humidity) if weather and weather.humidity else 60.0
            weather_code = encode_weather(weather.weather) if weather and weather.weather is not None else 0
            pm25 = float(weather.pm25) if weather and weather.pm25 else 40.0
            pm10 = float(weather.pm10) if weather and weather.pm10 else 60.0
            
            # 알림 후보 루틴들의 ID 리스트
            notification_routine_ids = [n["routine_id"] for n in notifications]
            
            # 최근 실행 기록 조회
            last_logs_query = (
                db.session.query(
                    RoutineExecution.routine_id,
                    RoutineExecution.run_time,
                    RoutineExecution.recommended_flag,
                    func.row_number()
                    .over(
                        partition_by=RoutineExecution.routine_id,
                        order_by=RoutineExecution.start_time.desc()
                    )
                    .label('rn')
                )
                .filter(
                    RoutineExecution.user_id == user_id,
                    RoutineExecution.routine_id.in_(notification_routine_ids)
                )
                .subquery()
            )
            
            last_logs_map = {}
            if notification_routine_ids:
                last_logs = (
                    db.session.query(last_logs_query)
                    .filter(last_logs_query.c.rn == 1)
                    .all()
                )
                for log in last_logs:
                    last_logs_map[log.routine_id] = {
                        'run_time': log.run_time,
                        'recommended_flag': log.recommended_flag
                    }
            
            # 우선순위 점수 계산을 위한 데이터 준비
            rows = []
            routine_id_to_notification = {n["routine_id"]: n for n in notifications}
            
            for routine_id, notification in routine_id_to_notification.items():
                routine = next((r for r in routines if r.id == routine_id), None)
                if not routine:
                    continue
                
                rt = encode_routine_type(routine.routine_type)
                st = encode_schedule_type(routine.schedule_type)
                preferred_hour = parse_preferred_time(routine.preferred_time)
                
                last_log = last_logs_map.get(routine.id)
                if last_log:
                    run_time = int(last_log['run_time'] or routine.run_minutes or 30)
                    recommended_flag = int(bool(last_log['recommended_flag']))
                else:
                    run_time = int(routine.run_minutes or 30)
                    recommended_flag = 0
                
                rows.append({
                    "ROUTINE_ID": routine.id,
                    "ROUTINE_NAME": routine.name,
                    "ROUTINE_TYPE": rt,
                    "SCHEDULE_TYPE": st,
                    "PREFERRED_TIME": preferred_hour,
                    "RUN_TIME": run_time,
                    "EXEC_HOUR": exec_hour,
                    "EXEC_DOW": exec_dow,
                    "RUN_MINUTES": int(routine.run_minutes or 30),
                    "RECOMMENDED_FLAG": recommended_flag,
                    "TEMPERATURE": temp,
                    "HUMIDITY": humi,
                    "WEATHER": weather_code,
                    "PM25": pm25,
                    "PM10": pm10,
                })
            
            # 우선순위 점수 계산
            if rows:
                df = pd.DataFrame(rows)
                missing = [c for c in feature_cols if c not in df.columns]
                if not missing:
                    X = df[feature_cols]
                    preds = model.predict(X)
                    df["pred_priority_score"] = preds
                    
                    # 루틴 ID와 우선순위 점수 매핑
                    routine_id_to_priority = dict(zip(df["ROUTINE_ID"], df["pred_priority_score"]))
                    
                    # 각 알림에 우선순위 점수 추가
                    for notification in notifications:
                        routine_id = notification["routine_id"]
                        notification["priority_score"] = float(routine_id_to_priority.get(routine_id, 0.0))
                    
                    # 우선순위 점수가 높은 것부터 정렬, 같은 점수면 remaining이 큰 것부터
                    notifications.sort(key=lambda x: (x.get("priority_score", 0.0), x["remaining"]), reverse=True)
                    
                    current_app.logger.info(f"🔍 [UnusedNotification] 우선순위 점수 계산 완료:")
                    for i, notif in enumerate(notifications):
                        current_app.logger.info(f"  {i+1}. {notif['routine_name']}: 우선순위={notif.get('priority_score', 0.0):.2f}, 실행={notif['executions_this_month']}/{notif['expected_count']}, 부족={notif['remaining']}회")
                else:
                    # feature가 없으면 remaining 기준으로 정렬
                    current_app.logger.warning(f"⚠️ [UnusedNotification] ML 모델 feature 누락: {missing}, remaining 기준으로 정렬")
                    notifications.sort(key=lambda x: x["remaining"], reverse=True)
            else:
                # rows가 없으면 remaining 기준으로 정렬
                notifications.sort(key=lambda x: x["remaining"], reverse=True)
        else:
            # ML 모델이 없으면 remaining 기준으로 정렬
            current_app.logger.warning(f"⚠️ [UnusedNotification] ML 모델이 로드되지 않음, remaining 기준으로 정렬")
            notifications.sort(key=lambda x: x["remaining"], reverse=True)
        
        selected_notification = notifications[0]  # 가장 우선순위가 높은 루틴 반환
        current_app.logger.info(f"✅ [UnusedNotification] 선택된 알림: {selected_notification['routine_name']} (우선순위: {selected_notification.get('priority_score', 0.0):.2f}, 부족: {selected_notification['remaining']}회)")
        
        return jsonify({
            "has_notification": True,
            "notification": selected_notification
        }), 200
    else:
        # 알림이 없는 이유 로깅 및 상세 정보 반환
        current_app.logger.info(f"🔍 [UnusedNotification] 알림 없음 - 확인된 루틴 수: {len(routines)}")
        reason = ""
        routine_details = []
        
        if not routines:
            reason = "WEEKLY/MONTHLY 타입의 활성 루틴이 없습니다"
            current_app.logger.info(f"  - 이유: {reason}")
        else:
            reason = "모든 루틴이 예상 횟수를 채웠거나 초과했습니다"
            current_app.logger.info(f"  - 이유: {reason}")
            for routine in routines:
                # 각 루틴의 실행 횟수와 예상 횟수 계산
                if routine.schedule_type == 'WEEKLY':
                    today = now.date()
                    days_since_monday = today.weekday() - 1
                    week_start = today - timedelta(days=days_since_monday)
                    week_end = week_start + timedelta(days=6)
                    week_start_dt = datetime.combine(week_start, time.min)
                    week_end_dt = datetime.combine(week_end, time.max)
                    executions_count = RoutineExecution.query.filter(
                        RoutineExecution.user_id == user_id,
                        RoutineExecution.routine_id == routine.id,
                        RoutineExecution.status == 2,
                        RoutineExecution.start_time >= week_start_dt,
                        RoutineExecution.start_time <= week_end_dt
                    ).count()
                    expected_count = routine.schedule_frequency if routine.schedule_frequency else 1
                    time_period = "이번 주"
                else:  # MONTHLY
                    executions_count = executions_this_month
                    expected_count = routine.schedule_frequency if routine.schedule_frequency else 1
                    time_period = "이번 달"
                
                routine_details.append({
                    "routine_id": routine.id,
                    "routine_name": routine.name,
                    "schedule_type": routine.schedule_type,
                    "schedule_frequency": routine.schedule_frequency,
                    "executions_count": executions_count,
                    "expected_count": expected_count,
                    "time_period": time_period
                })
                current_app.logger.info(f"    - {routine.name} (ID={routine.id}): {time_period} {executions_count}/{expected_count}회")
        
        return jsonify({
            "has_notification": False,
            "notification": None,
            "reason": reason,
            "routines_checked": len(routines),
            "routine_details": routine_details
        }), 200


@recommend_bp.route("/robot-cleaner-notification", methods=["GET"])
def get_robot_cleaner_notification():
    """
    건조기 알림 정보 반환
    오늘 예상 실행 시간(preferred_time)이 지났는데 아직 실행되지 않은 경우 알림
    GET /api/recommend/robot-cleaner-notification?user_id=1
    """
    user_id = request.args.get("user_id", type=int, default=1)
    
    try:
        user = User.query.get(user_id)
    except DatabaseError as e:
        error_msg = str(e.orig) if hasattr(e, 'orig') else str(e)
        return jsonify({
            "error": "Database connection failed",
            "message": "Unable to connect to the database.",
            "details": error_msg,
        }), 503
    
    if not user:
        return jsonify({"error": "user not found"}), 404
    
    # 건조기 루틴 찾기
    robot_cleaner_routine = Routine.query.filter_by(
        user_id=user_id,
        is_active=True
    ).filter(
        or_(
            Routine.name.like('%건조기%'),
            Routine.name.like('%dryer%'),
            Routine.name.like('%DRYER%')
        )
    ).first()
    
    if not robot_cleaner_routine:
        return jsonify({
            "has_notification": False,
            "notification": None
        }), 200
    
    # preferred_time이 없으면 알림 표시 안 함
    if not robot_cleaner_routine.preferred_time:
        return jsonify({
            "has_notification": False,
            "notification": None
        }), 200
    
    # preferred_time 파싱 (예: "14:00" 또는 "14" 형태)
    from .maping import parse_preferred_time
    preferred_hour = parse_preferred_time(robot_cleaner_routine.preferred_time)
    
    now = datetime.now()
    current_hour = now.hour
    current_minute = now.minute
    today = now.date()
    
    # preferred_time을 시간으로 변환 (예: 14:00)
    preferred_time_str = robot_cleaner_routine.preferred_time
    preferred_minute = 0
    if ':' in preferred_time_str:
        try:
            time_parts = preferred_time_str.split(':')
            preferred_hour = int(time_parts[0])
            preferred_minute = int(time_parts[1]) if len(time_parts) > 1 else 0
        except (ValueError, IndexError):
            preferred_minute = 0
    else:
        # "14" 형태인 경우
        preferred_hour = preferred_hour
        preferred_minute = 0
    
    # 예상 실행 시간이 지났는지 확인
    current_time_minutes = current_hour * 60 + current_minute
    preferred_time_minutes = preferred_hour * 60 + preferred_minute
    
    if current_time_minutes < preferred_time_minutes:
        # 아직 예상 시간이 지나지 않음
        return jsonify({
            "has_notification": False,
            "notification": None
        }), 200
    
    # 오늘 실행 기록 확인 (status는 숫자 2로 저장됨: 완료)
    today_start = datetime.combine(today, time.min)
    today_end = datetime.combine(today + timedelta(days=1), time.min)
    
    today_execution = RoutineExecution.query.filter(
        RoutineExecution.user_id == user_id,
        RoutineExecution.routine_id == robot_cleaner_routine.id,
        RoutineExecution.status == 2,  # 완료 상태 (숫자)
        RoutineExecution.start_time >= today_start,
        RoutineExecution.start_time < today_end
    ).first()
    
    # 오늘 실행 기록이 있으면 알림 표시 안 함
    if today_execution:
        return jsonify({
            "has_notification": False,
            "notification": None
        }), 200
    
    # 예상 시간이 지났고 오늘 실행되지 않았으므로 알림 표시
    time_passed_minutes = current_time_minutes - preferred_time_minutes
    hours_passed = time_passed_minutes // 60
    minutes_passed = time_passed_minutes % 60
    
    if hours_passed > 0:
        message = f'건조기 실행 시간이 {hours_passed}시간 지났어요.\n지금 안돌리면 입을 옷이 없어요'
    else:
        message = f'건조기 실행 시간이 {minutes_passed}분 지났어요.\n지금 안돌리면 입을 옷이 없어요'
    
    return jsonify({
        "has_notification": True,
        "notification": {
            "message": message,
            "robot_cleaner_routine_id": robot_cleaner_routine.id,
            "preferred_time": robot_cleaner_routine.preferred_time,
            "hours_passed": hours_passed,
        }
    }), 200


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
    import time as time_module
    start_time = time_module.time()
    
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
    
    current_app.logger.info(f"[DASHBOARD] 시작: user_id={user_id}, year={year}, month={month}")

    # -------------------------------
    # 1) 월간 실행 로그 집계 (성능 최적화: 하나의 쿼리로 통합)
    # CASE WHEN을 사용하여 인덱스를 한 번만 스캔하여 두 개의 COUNT를 계산
    # -------------------------------
    from sqlalchemy import func, case, or_, cast, String
    
    query_start = time_module.time()
    status_counts = (
        db.session.query(
            func.sum(case((RoutineExecution.status == 2, 1), else_=0)).label('completed'),
            func.sum(case((RoutineExecution.status == 3, 1), else_=0)).label('failed')
        )
        .filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.start_time >= start_dt,
            RoutineExecution.start_time < next_month_dt,
            RoutineExecution.status.in_([2, 3])  # 완료 또는 실패만 필터링 (숫자)
        )
        .first()
    )
    
    completed_count = int(status_counts[0] or 0) if status_counts else 0
    failed_count = int(status_counts[1] or 0) if status_counts else 0
    
    current_app.logger.info(f"[DASHBOARD] 상태별 카운트 쿼리: {time_module.time() - query_start:.2f}초, completed={completed_count}, failed={failed_count}")
    
    # 미룬 루틴 수: PENDING 상태이면서 오늘 날짜가 지난 루틴
    # 또는 특정 규칙에 따라 계산 (현재는 0으로 설정, 필요시 로직 추가)
    postponed_count = 0
    
    # 성능 최적화: 불필요한 디버깅 로그 제거

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
    # 성능 최적화: 불필요한 디버깅 코드 제거 및 단일 쿼리로 최적화
    query_start = time_module.time()
    from sqlalchemy import or_
    habit_routine = (
        Routine.query
        .filter(
            Routine.user_id == user_id,
            or_(Routine.is_active == True, Routine.is_active == 1),
            Routine.habit_goal_days.isnot(None),
        )
        .order_by(Routine.habit_start_date.asc().nulls_last())
        .first()
    )
    current_app.logger.info(f"[DASHBOARD] 습관 루틴 조회: {time_module.time() - query_start:.2f}초")

    if habit_routine and habit_routine.habit_goal_days:
        goal_days = int(habit_routine.habit_goal_days)
        # 시작일 없으면 월 시작일로 대체
        start_date = habit_routine.habit_start_date or start_dt.date()
        
        # 성능 최적화: 완료한 날짜 수 계산
        # Oracle에서 날짜 추출이 복잡하므로, 최소한의 데이터만 가져와서 Python에서 처리
        # start_time만 선택하여 네트워크 전송량 최소화
        # 성능 최적화: LIMIT 추가 및 인덱스 활용
        query_start = time_module.time()
        habit_logs = (
            db.session.query(RoutineExecution.start_time)
            .filter(
                RoutineExecution.user_id == user_id,
                RoutineExecution.routine_id == habit_routine.id,
                RoutineExecution.status == 2,  # DONE (숫자)
                RoutineExecution.start_time >= datetime.combine(start_date, time.min),
                RoutineExecution.start_time < next_month_dt,
            )
            .limit(100)  # 성능 최적화: 한 달에 100일 이상 완료는 불가능하므로 제한
            .all()
        )
        current_app.logger.info(f"[DASHBOARD] 습관 로그 조회: {time_module.time() - query_start:.2f}초, 로그 수={len(habit_logs)}")
        
        # 날짜만 추출하여 중복 제거
        done_dates = {log[0].date() for log in habit_logs if log[0]}
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

    response_data = {
        "user_id": user_id,
        "year": year,
        "month": month,
        "monthly_summary": monthly_summary,
        "habit": habit_info,
    }
    
    total_time = time_module.time() - start_time
    current_app.logger.info(f"[DASHBOARD] 전체 처리 시간: {total_time:.2f}초")
    
    return jsonify(response_data)


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
            temperature=1.0,
            humidity=30.0,
            weather="맑음",   # 또는 "SUNNY"
            pm25=10.5,
            pm10=22.0,
        )
        db.session.add(weather)
        db.session.flush()

    base_created = datetime.combine(target_date, time(0, 0))

    # 3) Routines 3개 생성 (문자열로 저장)
    r_morning = Routine(  # type: ignore
        id=9001,
        user_id=user_id,
        name="세탁기 돌리기",
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
        name="바닥 청소하기",
        routine_type="CLEANING",
        serial_no="CL001",
        run_minutes=20,
        schedule_type="DAILY",
        is_active=True,
        preferred_time="11:00",
        created_at=base_created,
    )
    db.session.add(r_noon)

    r_evening = Routine(  # type: ignore
        id=9003,
        user_id=user_id,
        name="설거지 하기",
        routine_type="washing",
        serial_no="DR001",
        run_minutes=15,
        schedule_type="DAILY",
        is_active=True,
        preferred_time="19:00",
        created_at=base_created,
    )
    db.session.add(r_evening)
    
    # 습관 목표 설정: 세탁기 돌리기(9001)를 21일 목표로 설정 (시연용)
    r_morning.habit_goal_days = 28
    r_morning.habit_start_date = target_date  # 시작일을 target_date로 설정

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

@recommend_bp.route("/set-habit-goal", methods=["POST", "GET"])
def set_habit_goal():
    """
    습관 목표를 설정하는 테스트 엔드포인트.
    예: GET /api/recommend/set-habit-goal?routine_id=9001&goal_days=21&start_date=2025-12-01
    """
    try:
        # GET 파라미터에서 가져오기
        routine_id = request.args.get("routine_id", type=int)
        goal_days = request.args.get("goal_days", type=int)
        start_date_str = request.args.get("start_date")
        
        # POST JSON에서 가져오기 (GET에 없으면)
        if request.is_json:
            data = request.get_json() or {}
            routine_id = routine_id or data.get("routine_id")
            goal_days = goal_days or data.get("goal_days")
            start_date_str = start_date_str or data.get("start_date")
        
        current_app.logger.info(f"[SET_HABIT_GOAL] routine_id={routine_id}, goal_days={goal_days}, start_date={start_date_str}")
        
        if not routine_id or not goal_days:
            return jsonify({"error": "routine_id and goal_days are required", "received": {"routine_id": routine_id, "goal_days": goal_days}}), 400
        
        routine = Routine.query.get(routine_id)
        if not routine:
            return jsonify({"error": "routine not found"}), 404
        
        # 직접 SQL로 업데이트 (SQLAlchemy ORM이 제대로 작동하지 않을 수 있음)
        from sqlalchemy import text
        if start_date_str:
            update_sql = text("""
                UPDATE routines 
                SET HABIT_GOAL_DAYS = :goal_days,
                    HABIT_START_DATE = TO_DATE(:start_date, 'YYYY-MM-DD')
                WHERE id = :routine_id
            """)
            db.session.execute(update_sql, {
                "goal_days": goal_days,
                "start_date": start_date_str,
                "routine_id": routine_id
            })
        else:
            update_sql = text("""
                UPDATE routines 
                SET HABIT_GOAL_DAYS = :goal_days
                WHERE id = :routine_id
            """)
            db.session.execute(update_sql, {
                "goal_days": goal_days,
                "routine_id": routine_id
            })
        
        db.session.commit()
        
        # 업데이트 확인
        check_sql = text("SELECT HABIT_GOAL_DAYS, HABIT_START_DATE FROM routines WHERE id = :routine_id")
        result = db.session.execute(check_sql, {"routine_id": routine_id}).fetchone()
        
        return jsonify({
            "status": "ok",
            "routine_id": routine_id,
            "habit_goal_days": result[0] if result else None,
            "habit_start_date": str(result[1]) if result and result[1] else None,
        })
    except Exception as e:
        current_app.logger.exception("set_habit_goal error")
        return jsonify({"error": str(e)}), 500

@recommend_bp.route("/seed-demo", methods=["POST", "GET"])
def seed_demo_endpoint():
    """
    테스트용 더미 데이터를 생성하는 엔드포인트.
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

