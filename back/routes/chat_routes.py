# routes/chat_routes.py
from flask import Blueprint, request, jsonify, current_app
from datetime import datetime, date, time, timedelta
import os
import re
from pathlib import Path
from dotenv import load_dotenv
import google.generativeai as genai
# .env 파일 로드 (app.py와 동일한 방식)
# 여러 경로에서 시도
project_root = Path(__file__).parent.parent
env_paths = [
    project_root / "Project" / ".env",  # back/Project/.env
    project_root / ".env",               # back/.env
    Path(__file__).parent / ".env",      # back/routes/.env
]

for env_path in env_paths:
    if env_path.exists():
        load_dotenv(dotenv_path=env_path, override=False)
        print(f"[INFO] Loaded .env from: {env_path}")
        break

from models import Routine, RoutineExecution
from .maping import (
    is_scheduled_today, normalize_routine_name, is_done_today,
    encode_routine_type, encode_schedule_type, encode_weather, parse_preferred_time, is_failed_today,
    is_goal_achieved,
    REVERSE_ROUTINE_TYPE, REVERSE_SCHEDULE_TYPE, REVERSE_WEATHER
)

chat_bp = Blueprint("chat", __name__)

# 테스트용 엔드포인트
@chat_bp.route("/test", methods=["GET"])
def test():
    """서버 연결 테스트용"""
    return jsonify({"status": "ok", "message": "Chat API is working!"})

# --- Gemini 클라이언트 초기화 (지연 초기화) ---
gemini_model = None
gemini_model_name = None

def _init_gemini_model():
    """Gemini 모델 초기화 (필요할 때 호출)"""
    global gemini_model, gemini_model_name
    
    if gemini_model is not None:
        return gemini_model  # 이미 초기화됨
    
    # 환경변수에서 API 키 가져오기
    API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    
    if not API_KEY:
        # .env 파일 다시 로드 시도
        project_root = Path(__file__).parent.parent
        env_paths = [
            project_root / "Project" / ".env",
            project_root / ".env",
        ]
        for env_path in env_paths:
            if env_path.exists():
                load_dotenv(dotenv_path=env_path, override=True)
                API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
                if API_KEY:
                    print(f"[INFO] Loaded API key from: {env_path}")
                    break
    
    if not API_KEY:
        print("[WARNING] GEMINI_API_KEY not found")
        return None
    
    try:
        genai.configure(api_key=API_KEY)
        # 사용 가능한 모델 확인 및 초기화
        # API에서 반환하는 실제 모델 이름 사용 (models/ 접두사 포함)
        model_candidates = [
            "models/gemini-2.0-flash",     # 최신 빠른 모델
            "models/gemini-2.5-flash",     # 최신 빠른 모델
            "models/gemini-2.5-pro",       # 최신 고성능 모델
            "models/gemini-2.0-flash-exp", # 실험 버전
            "models/gemini-1.5-flash",     # 이전 버전
            "models/gemini-1.5-pro",       # 이전 버전
        ]
        
        for model_name in model_candidates:
            try:
                # 모델 객체만 생성 (테스트 요청 없이)
                test_model = genai.GenerativeModel(model_name)
                gemini_model = test_model
                gemini_model_name = model_name
                print(f"[OK] Gemini model initialized: {model_name}")
                return gemini_model
            except Exception as e:
                error_msg = str(e)
                if "not found" in error_msg or "not supported" in error_msg:
                    print(f"[INFO] Model {model_name} not available: {error_msg[:80]}")
                    continue
                # API 키 오류면 다음 모델 시도
                if "API_KEY" in error_msg or "API key" in error_msg or "API_KEY" in error_msg.upper():
                    print(f"[ERROR] API key issue with {model_name}: {error_msg[:100]}")
                    continue
                # 기타 오류는 일단 이 모델 사용 시도
                gemini_model = test_model
                gemini_model_name = model_name
                print(f"[WARNING] Model {model_name} initialized with warning: {error_msg[:100]}")
                return gemini_model
        
        print("[WARNING] No available Gemini model found")
        return None
    except Exception as e:
        print(f"[ERROR] Gemini initialization failed: {str(e)[:200]}")
        return None


def build_context_for_user(user_id: int, selected_routine_ids: list[int] = None) -> str:
    """
    우리 서비스 DB를 조회해서,
    - 오늘 해야 할 루틴 리스트 (완료되지 않고 실패하지 않은 루틴만)
    를 텍스트로 정리해서 반환.
    
    Args:
        user_id: 사용자 ID
        selected_routine_ids: 선택된 루틴 ID 리스트 (None이면 모든 루틴 사용)
    """
    today = date.today()

    # === 오늘 루틴 ===
    routines = Routine.query.filter_by(user_id=user_id, is_active=True).all()
    today_items: list[str] = []
    today_routine_ids = []  # 디버깅용

    # 디버깅: 전체 루틴 정보 로깅
    from flask import current_app
    current_app.logger.info(f"[CHAT build_context] 전체 활성 루틴 개수: {len(routines)}")
    for r in routines:
        current_app.logger.info(f"[CHAT build_context] 루틴 ID={r.id}, name={r.name}, schedule_type={r.schedule_type}, created_at={r.created_at}")

    for r in routines:
        # 선택된 루틴 ID가 있으면 그 루틴들만 포함
        if selected_routine_ids is not None and len(selected_routine_ids) > 0:
            if r.id not in selected_routine_ids:
                current_app.logger.info(f"[CHAT build_context] 루틴 {r.id} ({r.name}): 선택된 루틴 ID에 없어서 제외")
                continue
        
        # 채팅봇에서는 is_scheduled_today 체크 제거 (VIEW ALL과 동일하게 모든 활성 루틴 표시)
        # 완료/실패/목표 달성 여부만 확인
        st = (r.schedule_type or "").upper()
        
        is_done = is_done_today(r, user_id, today)
        is_failed = is_failed_today(r, user_id, today)
        is_goal = is_goal_achieved(r, user_id, today)
        
        current_app.logger.info(f"[CHAT build_context] 루틴 {r.id} ({r.name}): schedule_type={st}, is_done={is_done}, is_failed={is_failed}, is_goal={is_goal}")
        if is_done:
            current_app.logger.info(f"[CHAT build_context] 루틴 {r.id} ({r.name}): 오늘 완료되어서 제외")
            continue
        if is_failed:
            current_app.logger.info(f"[CHAT build_context] 루틴 {r.id} ({r.name}): 오늘 실패해서 제외")
            continue
        # WEEKLY/MONTHLY 루틴의 목표 달성 여부 확인 (목표 달성된 루틴은 제외)
        if is_goal:
            current_app.logger.info(f"[CHAT build_context] 루틴 {r.id} ({r.name}): 목표 달성되어서 제외")
            continue

        # 원본 이름과 정규화된 이름 모두 로깅
        original_name = r.name or ""
        normalized_name = normalize_routine_name(original_name)
        
        name = normalized_name
        minutes = r.run_minutes or 0
        today_items.append(f"- {name} (예상 {minutes}분)")
        today_routine_ids.append(r.id)  # 디버깅용
        current_app.logger.info(f"[CHAT build_context] 루틴 {r.id} ({r.name}): 오늘 루틴 목록에 추가됨")

    if not today_items:
        today_text = "오늘 스케줄된 루틴은 없습니다."
    else:
        today_text = "\n".join(today_items)

    # 날씨 정보 추가 (오늘 + 내일)
    weather_info_text = ""
    try:
        from models import WeatherInfo
        from flask import current_app
        
        # 디버깅: 조회할 날짜 확인
        current_app.logger.info(f"[CHAT 날씨] 오늘 날짜: {today.isoformat()}")
        
        # 오늘 날씨 - Oracle 호환성을 위해 명시적 쿼리 사용
        from sqlalchemy import func
        weather_today = WeatherInfo.query.filter(
            func.TRUNC(WeatherInfo.date) == func.TRUNC(today)
        ).first()
        # 대안: filter_by도 시도
        if not weather_today:
            weather_today = WeatherInfo.query.filter_by(date=today).first()
        current_app.logger.info(f"[CHAT 날씨] 오늘 날짜: {today.isoformat()}, 조회 결과: {weather_today}")
        if weather_today:
            current_app.logger.info(f"[CHAT 날씨] 오늘 날씨 (DB): weather={weather_today.weather}, temp={weather_today.temperature}, humi={weather_today.humidity}, date={weather_today.date}")
        else:
            current_app.logger.warning(f"[CHAT 날씨] 오늘 날씨 데이터 없음!")
        
        # 내일 날씨
        tomorrow = today + timedelta(days=1)
        current_app.logger.info(f"[CHAT 날씨] 내일 날짜: {tomorrow.isoformat()}")
        
        # 모든 날씨 데이터를 먼저 확인 (디버깅용)
        all_weather = WeatherInfo.query.order_by(WeatherInfo.date.desc()).limit(20).all()
        current_app.logger.info(f"[CHAT 날씨] 전체 날씨 데이터 개수 (최근 20개): {len(all_weather)}")
        matching_weather = None
        for w in all_weather:
            current_app.logger.info(f"[CHAT 날씨] 날씨 데이터: date={w.date} (type={type(w.date)}), weather={w.weather}, temp={w.temperature}, humi={w.humidity}")
            # 내일 날짜와 비교
            if w.date:
                try:
                    if isinstance(w.date, date):
                        date_diff = (w.date - tomorrow).days
                        current_app.logger.info(f"[CHAT 날씨] 날짜 차이: {date_diff}일 (내일과 비교)")
                        if date_diff == 0:
                            current_app.logger.info(f"[CHAT 날씨] ✅ 내일 날짜와 일치하는 데이터 발견! weather={w.weather}")
                            matching_weather = w
                except Exception as e:
                    current_app.logger.warning(f"[CHAT 날씨] 날짜 비교 오류: {e}")
        
        # Oracle 호환성을 위해 명시적 쿼리 사용
        weather_tomorrow = None
        # 방법 1: TRUNC 사용
        try:
            weather_tomorrow = WeatherInfo.query.filter(
                func.TRUNC(WeatherInfo.date) == func.TRUNC(tomorrow)
            ).first()
            if weather_tomorrow:
                current_app.logger.info(f"[CHAT 날씨] 방법1(TRUNC) 성공: weather={weather_tomorrow.weather}")
        except Exception as e:
            current_app.logger.warning(f"[CHAT 날씨] 방법1(TRUNC) 실패: {e}")
        
        # 방법 2: filter_by 사용
        if not weather_tomorrow:
            try:
                weather_tomorrow = WeatherInfo.query.filter_by(date=tomorrow).first()
                if weather_tomorrow:
                    current_app.logger.info(f"[CHAT 날씨] 방법2(filter_by) 성공: weather={weather_tomorrow.weather}")
            except Exception as e:
                current_app.logger.warning(f"[CHAT 날씨] 방법2(filter_by) 실패: {e}")
        
        # 방법 3: 문자열 비교 사용
        if not weather_tomorrow:
            try:
                tomorrow_str = tomorrow.isoformat()
                weather_tomorrow = WeatherInfo.query.filter(
                    func.TO_CHAR(WeatherInfo.date, 'YYYY-MM-DD') == tomorrow_str
                ).first()
                if weather_tomorrow:
                    current_app.logger.info(f"[CHAT 날씨] 방법3(TO_CHAR) 성공: weather={weather_tomorrow.weather}")
            except Exception as e:
                current_app.logger.warning(f"[CHAT 날씨] 방법3(TO_CHAR) 실패: {e}")
        
        # 방법 4: 수동으로 찾은 데이터 사용
        if not weather_tomorrow and matching_weather:
            current_app.logger.info(f"[CHAT 날씨] 방법4(수동 매칭) 사용: weather={matching_weather.weather}")
            weather_tomorrow = matching_weather
        
        current_app.logger.info(f"[CHAT 날씨] 내일 날씨 최종 조회 결과: {weather_tomorrow}")
        if weather_tomorrow:
            current_app.logger.info(f"[CHAT 날씨] 내일 날씨 (DB): weather={weather_tomorrow.weather}, temp={weather_tomorrow.temperature}, humi={weather_tomorrow.humidity}, date={weather_tomorrow.date}")
        else:
            current_app.logger.error(f"[CHAT 날씨] ❌ 내일 날씨 데이터 없음! (조회한 날짜: {tomorrow.isoformat()})")
        
        weather_parts = []
        
        # 기온을 자연어로 변환하는 함수
        def get_temp_description(temp):
            if temp is None:
                return None
            if temp < 10:
                return "추움"
            elif temp <= 25:
                return "따뜻함"
            else:
                return "더움"
        
        # 습도를 자연어로 변환하는 함수
        def get_humidity_description(humi):
            if humi is None:
                return None
            if humi < 50:
                return "낮음"
            else:
                return "높음"
        
        # 오늘 날씨 정보
        if weather_today:
            temp = float(weather_today.temperature) if weather_today.temperature else None
            humi = float(weather_today.humidity) if weather_today.humidity else None
            weather_desc = weather_today.weather if weather_today.weather else None
            
            today_parts = []
            if weather_desc:
                today_parts.append(f"날씨: {weather_desc}")
            temp_desc = get_temp_description(temp)
            if temp_desc:
                today_parts.append(f"기온: {temp_desc}")
            humi_desc = get_humidity_description(humi)
            if humi_desc:
                today_parts.append(f"습도: {humi_desc}")
            
            if today_parts:
                weather_parts.append(f"오늘 - {', '.join(today_parts)}")
        
        # 내일 날씨 정보
        if weather_tomorrow:
            temp_tomorrow = float(weather_tomorrow.temperature) if weather_tomorrow.temperature else None
            humi_tomorrow = float(weather_tomorrow.humidity) if weather_tomorrow.humidity else None
            weather_desc_tomorrow = weather_tomorrow.weather if weather_tomorrow.weather else None
            
            # 디버깅: 내일 날씨 정보 로깅
            from flask import current_app
            current_app.logger.info(f"[CHAT 날씨] 내일 날짜: {tomorrow.isoformat()}")
            current_app.logger.info(f"[CHAT 날씨] 내일 날씨 (DB): {weather_desc_tomorrow}")
            current_app.logger.info(f"[CHAT 날씨] 내일 기온 (DB): {temp_tomorrow}")
            current_app.logger.info(f"[CHAT 날씨] 내일 습도 (DB): {humi_tomorrow}")
            
            tomorrow_parts = []
            if weather_desc_tomorrow:
                tomorrow_parts.append(f"날씨: {weather_desc_tomorrow}")
            temp_tomorrow_desc = get_temp_description(temp_tomorrow)
            if temp_tomorrow_desc:
                tomorrow_parts.append(f"기온: {temp_tomorrow_desc}")
            humi_tomorrow_desc = get_humidity_description(humi_tomorrow)
            if humi_tomorrow_desc:
                tomorrow_parts.append(f"습도: {humi_tomorrow_desc}")
            
            if tomorrow_parts:
                weather_parts.append(f"내일 - {', '.join(tomorrow_parts)}")
                current_app.logger.info(f"[CHAT 날씨] 내일 날씨 정보 (컨텍스트): {', '.join(tomorrow_parts)}")
        else:
            from flask import current_app
            current_app.logger.warning(f"[CHAT 날씨] 내일 날씨 데이터 없음: {tomorrow.isoformat()}")
        
        if weather_parts:
            weather_info_text = " | ".join(weather_parts)
    except Exception as e:
        from flask import current_app
        current_app.logger.exception("날씨 정보 조회 오류")

    ctx_lines = [
        f"오늘 날짜: {today.isoformat()}",
    ]
    
    if weather_info_text:
        ctx_lines.append(f"날씨 정보: {weather_info_text}")
        # 디버깅: 날씨 정보 로깅
        from flask import current_app
        current_app.logger.info(f"[CHAT 날씨] 최종 날씨 정보 (컨텍스트): {weather_info_text}")
    
    ctx_lines.extend([
        "",
        "[오늘 해야 할 루틴]",
        today_text,
    ])
    context_str = "\n".join(ctx_lines)
    
    # 디버깅: build_context 결과 확인
    from flask import current_app
    current_app.logger.info(f"[CHAT build_context] 전체 루틴 개수 (DB): {len(routines)}")
    current_app.logger.info(f"[CHAT build_context] 오늘 루틴 항목 개수: {len(today_items)}")
    current_app.logger.info(f"[CHAT build_context] 오늘 루틴 IDs: {today_routine_ids}")
    current_app.logger.info(f"[CHAT build_context] 오늘 루틴 이름들 (정규화 전): {[r.name for r in routines if r.id in today_routine_ids]}")
    current_app.logger.info(f"[CHAT build_context] 오늘 루틴 이름들 (정규화 후): {[item.split('(')[0].strip('- ').strip() for item in today_items]}")
    
    return context_str


@chat_bp.route("/chat", methods=["POST"])
def chat():
    """
    프론트에서 호출:
    POST /api/chat/chat  (아래 app.py 설정 기준)
    body: { "user_id": 1, "message": "오늘 뭐부터 해야 돼?" }
    """
    # 지연 초기화: 필요할 때 Gemini 모델 초기화 시도
    gemini_model_instance = _init_gemini_model()
    if gemini_model_instance is None:
        return jsonify({
            "error": "no_gemini_api_key",
            "message": "서버에 GEMINI_API_KEY 환경변수가 설정되지 않았습니다. .env 파일을 확인해주세요."
        }), 500

    data = request.get_json() or {}
    user_id = data.get("user_id", 1)
    user_message = data.get("message")
    selected_routine_ids = data.get("selected_routine_ids")  # 선택된 루틴 ID 리스트

    if not user_message:
        return jsonify({"error": "message is required"}), 400
    
    # 선택된 루틴 ID 로깅
    if selected_routine_ids:
        current_app.logger.info(f"[CHAT] 선택된 루틴 ID들: {selected_routine_ids}")
    else:
        current_app.logger.info(f"[CHAT] 선택된 루틴 ID 없음 - 모든 루틴 사용")

    # 1) 요청 타입 감지
    priority_keywords = ["우선순위", "중요한 순위", "어떤 순서", "순서대로", "뭐부터", "먼저 해야 할", "우선적으로"]
    is_priority_request = any(keyword in user_message for keyword in priority_keywords)
    
    # 루틴 추천 요청 감지 (VIEW ALL 리스트의 모든 루틴 대상)
    routine_recommend_keywords = ["루틴 추천", "루틴 추천해", "루틴 추천해줘", "루틴 추천해주", "추천 루틴", "추천해줘", "추천해주세요"]
    is_routine_recommend_request = any(keyword in user_message for keyword in routine_recommend_keywords)

    priority_data = None
    routine_recommend_data = None
    
    # 루틴 추천 요청 처리 (VIEW ALL 리스트의 모든 루틴 대상)
    if is_routine_recommend_request:
        try:
            from Project.extensions import db
            from models import User, WeatherInfo
            import pandas as pd
            
            # XGBoost 모델 (우선순위 계산용)
            xgb_model = current_app.model
            feature_cols = current_app.feature_cols
            
            if xgb_model is not None and feature_cols is not None:
                today = date.today()
                now = datetime.now()
                exec_hour = now.hour
                exec_dow = now.weekday()
                
                # 사용자와 루틴 조회 (VIEW ALL 리스트 = 모든 활성 루틴)
                user = User.query.get(user_id)
                if user:
                    # 모든 활성 루틴 가져오기 (오늘 스케줄 여부와 관계없이)
                    all_routines = Routine.query.filter_by(user_id=user_id, is_active=True).all()
                    
                    # 목표 달성된 WEEKLY/MONTHLY 루틴 필터링
                    filtered_routines = []
                    for r in all_routines:
                        # WEEKLY/MONTHLY 루틴의 경우 목표 달성 여부 확인
                        st = (r.schedule_type or "").upper()
                        if st in ("WEEKLY", "MONTHLY"):
                            if is_goal_achieved(r, user_id, today):
                                continue  # 목표 달성된 루틴은 제외
                        filtered_routines.append(r)
                    
                    current_app.logger.info(f"[CHAT] 루틴 추천 요청: 전체 {len(all_routines)}개 중 목표 미달성 {len(filtered_routines)}개 대상")
                    
                    if filtered_routines:
                        # 날씨 정보
                        weather = WeatherInfo.query.filter_by(date=today).first()
                        temp = float(weather.temperature) if weather and weather.temperature else 20.0
                        humi = float(weather.humidity) if weather and weather.humidity else 60.0
                        weather_code = encode_weather(weather.weather) if weather and weather.weather is not None else 0
                        pm25 = float(weather.pm25) if weather and weather.pm25 else 40.0
                        pm10 = float(weather.pm10) if weather and weather.pm10 else 60.0
                        
                        # 모델 입력 데이터 생성 (필터링된 루틴)
                        rows = []
                        for r in filtered_routines:
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
                        
                        # feature 순서 맞추기
                        missing = [c for c in feature_cols if c not in df.columns]
                        if not missing:
                            X = df[feature_cols]
                            preds = xgb_model.predict(X)
                            df["pred_priority_score"] = preds
                            
                            df_sorted = df.sort_values("pred_priority_score", ascending=False)
                            
                            # 가장 높은 우선순위 루틴 하나만 선택
                            if len(df_sorted) > 0:
                                top_row = df_sorted.iloc[0]
                                rt_val = int(top_row["ROUTINE_TYPE"])
                                st_val = int(top_row["SCHEDULE_TYPE"])
                                routine_recommend_data = {
                                    "routine_id": int(top_row["ROUTINE_ID"]),
                                    "routine_name": normalize_routine_name(str(top_row["ROUTINE_NAME"])),
                                    "pred_priority_score": float(top_row["pred_priority_score"]),
                                    "run_minutes": int(top_row["RUN_MINUTES"]),
                                    "routine_type": rt_val,
                                    "schedule_type": st_val,
                                    "routine_type_label": REVERSE_ROUTINE_TYPE.get(rt_val),
                                    "schedule_type_label": REVERSE_SCHEDULE_TYPE.get(st_val),
                                    "weather_label": REVERSE_WEATHER.get(weather_code),
                                }
                                
                                # 최근 실행 기록 추가
                                routine_id = routine_recommend_data["routine_id"]
                                try:
                                    last_log = RoutineExecution.query.filter_by(
                                        user_id=user_id, routine_id=routine_id
                                    ).order_by(RoutineExecution.start_time.desc()).first()
                                    
                                    if last_log and last_log.start_time:
                                        last_date = last_log.start_time.date()
                                        days_ago = (today - last_date).days
                                        days_ago_abs = abs(days_ago)
                                        if days_ago == 0:
                                            routine_recommend_data["last_exec_info"] = "오늘 실행함"
                                        elif days_ago == 1:
                                            routine_recommend_data["last_exec_info"] = "어제 실행함"
                                        elif days_ago_abs < 7:
                                            routine_recommend_data["last_exec_info"] = f"{days_ago_abs}일 전 실행함"
                                        else:
                                            routine_recommend_data["last_exec_info"] = f"{days_ago_abs}일 전 실행함 (오래됨)"
                                except Exception:
                                    routine_recommend_data["last_exec_info"] = None
                                
                                current_app.logger.info(f"[CHAT] 루틴 추천: {routine_recommend_data['routine_name']} (점수: {routine_recommend_data['pred_priority_score']:.2f})")
        except Exception as e:
            current_app.logger.exception("Routine recommend calculation error")
            routine_recommend_data = None
    
    if is_priority_request:
        # 우선순위 추천 데이터 가져오기
        try:
            # 우선순위 계산 로직 실행
            from Project.extensions import db
            from models import User, WeatherInfo
            import pandas as pd
            
            # XGBoost 모델 (우선순위 계산용)
            xgb_model = current_app.model
            feature_cols = current_app.feature_cols
            
            if xgb_model is not None and feature_cols is not None:
                today = date.today()
                now = datetime.now()
                exec_hour = now.hour
                exec_dow = now.weekday()
                
                # 사용자와 루틴 조회
                user = User.query.get(user_id)
                if user:
                    all_routines = Routine.query.filter_by(user_id=user_id, is_active=True).all()
                    routines = []
                    for r in all_routines:
                        # 선택된 루틴 ID가 있으면 그 루틴들만 포함
                        if selected_routine_ids and len(selected_routine_ids) > 0:
                            if r.id not in selected_routine_ids:
                                continue
                        
                        # 채팅봇에서는 is_scheduled_today 체크 제거 (VIEW ALL과 동일하게 모든 활성 루틴 표시)
                        # 완료/실패/목표 달성 여부만 확인
                        if is_done_today(r, user_id, today):
                            continue
                        if is_failed_today(r, user_id, today):
                            continue
                        # WEEKLY/MONTHLY 루틴의 목표 달성 여부 확인 (목표 달성된 루틴은 제외)
                        if is_goal_achieved(r, user_id, today):
                            continue
                        routines.append(r)
                    
                    # 디버깅: 실제 필터링된 루틴 개수 확인
                    current_app.logger.info(f"[CHAT] 필터링 결과: 전체 {len(all_routines)}개 중 오늘 스케줄된 {len(routines)}개 (routine_ids: {[r.id for r in routines]})")

                    if routines:
                        # 날씨 정보
                        weather = WeatherInfo.query.filter_by(date=today).first()
                        temp = float(weather.temperature) if weather and weather.temperature else 20.0
                        humi = float(weather.humidity) if weather and weather.humidity else 60.0
                        weather_code = encode_weather(weather.weather) if weather and weather.weather is not None else 0
                        pm25 = float(weather.pm25) if weather and weather.pm25 else 40.0
                        pm10 = float(weather.pm10) if weather and weather.pm10 else 60.0
                        
                        # 모델 입력 데이터 생성
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
                        
                        # feature 순서 맞추기
                        missing = [c for c in feature_cols if c not in df.columns]
                        if not missing:
                            X = df[feature_cols]
                            preds = xgb_model.predict(X)
                            df["pred_priority_score"] = preds
                            
                            df_sorted = df.sort_values("pred_priority_score", ascending=False)
                            
                            # JSON 변환 (필터링된 루틴만 - 오늘 스케줄 + 미완료 + 미실패)
                            priority_data = []
                            for _, row in df_sorted.iterrows():
                                rt_val = int(row["ROUTINE_TYPE"])
                                st_val = int(row["SCHEDULE_TYPE"])
                                priority_data.append({
                                    "routine_id": int(row["ROUTINE_ID"]),
                                    "routine_name": normalize_routine_name(str(row["ROUTINE_NAME"])),
                                    "pred_priority_score": float(row["pred_priority_score"]),
                                    "run_minutes": int(row["RUN_MINUTES"]),
                                    "routine_type": rt_val,
                                    "schedule_type": st_val,
                                    "routine_type_label": REVERSE_ROUTINE_TYPE.get(rt_val),
                                    "schedule_type_label": REVERSE_SCHEDULE_TYPE.get(st_val),
                                    "weather_label": REVERSE_WEATHER.get(weather_code),
                                })
                            
                            # 디버깅: 실제 필터링된 루틴 개수 확인
                            current_app.logger.info(f"[CHAT] 우선순위 계산 완료: {len(priority_data)}개 루틴 (routine_ids: {[p['routine_id'] for p in priority_data]})")
        except Exception as e:
            current_app.logger.exception("Priority calculation error")
            priority_data = None

    # 2) 우리 서비스 컨텍스트 만들기
    # 루틴 추천 요청인 경우: 가장 높은 우선순위 루틴 하나만 포함
    # 우선순위 요청인 경우: 우선순위 정보만 포함 (중복 방지)
    # 일반 요청인 경우: 전체 컨텍스트 포함
    
    if is_routine_recommend_request and routine_recommend_data:
        # 루틴 추천 요청: 가장 높은 우선순위 루틴 하나만 사용
        today = date.today()
        
        # 날씨 정보 추가 (오늘 + 내일)
        weather_info_text = ""
        try:
            from models import WeatherInfo
            # 오늘 날씨
            weather_today = WeatherInfo.query.filter_by(date=today).first()
            # 내일 날씨
            tomorrow = today + timedelta(days=1)
            weather_tomorrow = WeatherInfo.query.filter_by(date=tomorrow).first()
            
            weather_parts = []
            
            # 기온을 자연어로 변환하는 함수
            def get_temp_description(temp):
                if temp is None:
                    return None
                if temp < 10:
                    return "추움"
                elif temp <= 25:
                    return "따뜻함"
                else:
                    return "더움"
            
            # 습도를 자연어로 변환하는 함수
            def get_humidity_description(humi):
                if humi is None:
                    return None
                if humi < 50:
                    return "낮음"
                else:
                    return "높음"
            
            # 오늘 날씨 정보
            if weather_today:
                temp = float(weather_today.temperature) if weather_today.temperature else None
                humi = float(weather_today.humidity) if weather_today.humidity else None
                weather_desc = weather_today.weather if weather_today.weather else None
                
                today_parts = []
                if weather_desc:
                    today_parts.append(f"날씨: {weather_desc}")
                temp_desc = get_temp_description(temp)
                if temp_desc:
                    today_parts.append(f"기온: {temp_desc}")
                humi_desc = get_humidity_description(humi)
                if humi_desc:
                    today_parts.append(f"습도: {humi_desc}")
                
                if today_parts:
                    weather_parts.append(f"오늘 - {', '.join(today_parts)}")
            
            # 내일 날씨 정보
            if weather_tomorrow:
                temp_tomorrow = float(weather_tomorrow.temperature) if weather_tomorrow.temperature else None
                humi_tomorrow = float(weather_tomorrow.humidity) if weather_tomorrow.humidity else None
                weather_desc_tomorrow = weather_tomorrow.weather if weather_tomorrow.weather else None
                
                tomorrow_parts = []
                if weather_desc_tomorrow:
                    tomorrow_parts.append(f"날씨: {weather_desc_tomorrow}")
                temp_tomorrow_desc = get_temp_description(temp_tomorrow)
                if temp_tomorrow_desc:
                    tomorrow_parts.append(f"기온: {temp_tomorrow_desc}")
                humi_tomorrow_desc = get_humidity_description(humi_tomorrow)
                if humi_tomorrow_desc:
                    tomorrow_parts.append(f"습도: {humi_tomorrow_desc}")
                
                if tomorrow_parts:
                    weather_parts.append(f"내일 - {', '.join(tomorrow_parts)}")
            
            if weather_parts:
                weather_info_text = " | ".join(weather_parts)
        except Exception as e:
            current_app.logger.exception("날씨 정보 조회 오류")
        
        context_lines = [
            f"오늘 날짜: {today.isoformat()}",
        ]
        
        if weather_info_text:
            context_lines.append(f"날씨 정보: {weather_info_text}")
        
        context_lines.extend([
            "",
            "[추천 루틴 (가장 높은 우선순위)]",
        ])
        
        score = routine_recommend_data.get('pred_priority_score', 0)
        name = routine_recommend_data.get('routine_name', '알 수 없음')
        minutes = routine_recommend_data.get('run_minutes', 30)
        last_exec_info = routine_recommend_data.get('last_exec_info', '')
        
        context_lines.append(f"{name} (점수: {score:.2f}, 예상 {minutes}분{(' - ' + last_exec_info) if last_exec_info else ''})")
        
        context = "\n".join(context_lines)
        
        current_app.logger.info(f"[CHAT] 루틴 추천 모드: {name} (점수: {score:.2f})")
    elif is_priority_request and priority_data and isinstance(priority_data, list) and len(priority_data) > 0:
        # 우선순위 요청: 우선순위 섹션만 사용
        today = date.today()
        
        # 날씨 정보 추가 (우선순위 추천 이유 설명에 필요) - 오늘 + 내일
        weather_info_text = ""
        try:
            from models import WeatherInfo
            # 오늘 날씨
            weather_today = WeatherInfo.query.filter_by(date=today).first()
            # 내일 날씨
            tomorrow = today + timedelta(days=1)
            weather_tomorrow = WeatherInfo.query.filter_by(date=tomorrow).first()
            
            weather_parts = []
            
            # 기온을 자연어로 변환하는 함수
            def get_temp_description(temp):
                if temp is None:
                    return None
                if temp < 10:
                    return "추움"
                elif temp <= 25:
                    return "따뜻함"
                else:
                    return "더움"
            
            # 습도를 자연어로 변환하는 함수
            def get_humidity_description(humi):
                if humi is None:
                    return None
                if humi < 50:
                    return "낮음"
                else:
                    return "높음"
            
            # 오늘 날씨 정보
            if weather_today:
                temp = float(weather_today.temperature) if weather_today.temperature else None
                humi = float(weather_today.humidity) if weather_today.humidity else None
                weather_desc = weather_today.weather if weather_today.weather else None
                
                today_parts = []
                if weather_desc:
                    today_parts.append(f"날씨: {weather_desc}")
                temp_desc = get_temp_description(temp)
                if temp_desc:
                    today_parts.append(f"기온: {temp_desc}")
                humi_desc = get_humidity_description(humi)
                if humi_desc:
                    today_parts.append(f"습도: {humi_desc}")
                
                if today_parts:
                    weather_parts.append(f"오늘 - {', '.join(today_parts)}")
            
            # 내일 날씨 정보
            if weather_tomorrow:
                temp_tomorrow = float(weather_tomorrow.temperature) if weather_tomorrow.temperature else None
                humi_tomorrow = float(weather_tomorrow.humidity) if weather_tomorrow.humidity else None
                weather_desc_tomorrow = weather_tomorrow.weather if weather_tomorrow.weather else None
                
                tomorrow_parts = []
                if weather_desc_tomorrow:
                    tomorrow_parts.append(f"날씨: {weather_desc_tomorrow}")
                temp_tomorrow_desc = get_temp_description(temp_tomorrow)
                if temp_tomorrow_desc:
                    tomorrow_parts.append(f"기온: {temp_tomorrow_desc}")
                humi_tomorrow_desc = get_humidity_description(humi_tomorrow)
                if humi_tomorrow_desc:
                    tomorrow_parts.append(f"습도: {humi_tomorrow_desc}")
                
                if tomorrow_parts:
                    weather_parts.append(f"내일 - {', '.join(tomorrow_parts)}")
            
            if weather_parts:
                weather_info_text = " | ".join(weather_parts)
        except Exception as e:
            current_app.logger.exception("날씨 정보 조회 오류")
        
        context_lines = [
            f"오늘 날짜: {today.isoformat()}",
        ]
        
        if weather_info_text:
            context_lines.append(f"날씨 정보: {weather_info_text}")
        
        context_lines.extend([
            "",
            "[우선순위 추천 (점수 높은 순)]",
        ])
        
        # 각 루틴의 최근 실행 기록 정보 추가
        for idx, item in enumerate(priority_data, 1):
            score = item.get('pred_priority_score', 0)
            name = item.get('routine_name', '알 수 없음')
            minutes = item.get('run_minutes', 30)
            routine_id = item.get('routine_id')
            
            # 최근 실행 기록 확인
            last_exec_info = ""
            if routine_id:
                try:
                    last_log = RoutineExecution.query.filter_by(
                        user_id=user_id, routine_id=routine_id
                    ).order_by(RoutineExecution.start_time.desc()).first()
                    
                    if last_log and last_log.start_time:
                        last_date = last_log.start_time.date()
                        days_ago = (today - last_date).days
                        # 음수일 경우 절댓값 사용 (미래 날짜 처리)
                        days_ago_abs = abs(days_ago)
                        if days_ago == 0:
                            last_exec_info = " (오늘 실행함)"
                        elif days_ago == 1:
                            last_exec_info = " (어제 실행함)"
                        elif days_ago_abs < 7:
                            last_exec_info = f" ({days_ago_abs}일 전 실행함)"
                        else:
                            last_exec_info = f" ({days_ago_abs}일 전 실행함, 오래됨)"
                except Exception:
                    pass
            
            context_lines.append(f"{idx}. {name} (점수: {score:.2f}, 예상 {minutes}분{last_exec_info})")
        
        context = "\n".join(context_lines)
        
        # 디버깅
        current_app.logger.info(f"[CHAT] 우선순위 모드: {len(priority_data)}개 루틴만 전달")
        current_app.logger.info(f"[CHAT] 우선순위 루틴 IDs: {[item.get('routine_id') for item in priority_data]}")
    else:
        # 일반 요청: 전체 컨텍스트
        try:
            context = build_context_for_user(user_id, selected_routine_ids)
        except Exception as e:
            current_app.logger.exception("build_context_for_user error")
            context = "오늘의 루틴/기록 정보를 불러오지 못했습니다."
    
    # 디버깅: 최종 컨텍스트 확인
    current_app.logger.info(f"[CHAT] 최종 컨텍스트 길이: {len(context)} 문자")
    current_app.logger.info(f"[CHAT] 최종 컨텍스트 (처음 500자): {context[:500]}")

     # 4) Gemini에 넘길 프롬프트 구성
    if is_routine_recommend_request and routine_recommend_data:
        # 루틴 추천 요청: 가장 높은 우선순위 루틴 하나만 추천
        prompt = f"""
[중요 규칙]
- 본인 소개나 역할 설명은 하지 마세요. 바로 답변을 시작하세요.
- '[추천 루틴 (가장 높은 우선순위)]' 섹션에 나열된 루틴 하나만 추천하세요.
- 사용자가 새로운 루틴을 만들거나 정보에 없는 루틴을 추가하라고 요청하면 날씨를 참고해 가전 루틴을 추천하세요.
- 모든 숫자, 시간, 횟수, 날짜는 '[오늘의 정보]'에 있는 값만 사용하세요.
- 날씨, 온도, 습도 등 요소를 이용하여 추천 이유를 설명하세요.
- 주의: '[추천 루틴 (가장 높은 우선순위)]' 섹션에 나열된 루틴은 이미 목표 달성 여부를 확인한 루틴입니다. 
  WEEKLY(주간) 루틴은 이번 주 목표 횟수를 달성했으면 다음 주부터, 
  MONTHLY(월간) 루틴은 이번 달 목표 횟수를 달성했으면 다음 달부터 추천되어야 합니다.
  하지만 섹션에 나열된 루틴은 이미 필터링되어 있으므로 그대로 추천하시면 됩니다.

[오늘의 정보]
{context}

[사용자 질문]
{user_message}

위 정보를 바탕으로, '[추천 루틴 (가장 높은 우선순위)]' 섹션의 루틴 하나를 추천해주세요.
다음 내용을 포함하세요:
- 루틴 내용 (무엇을 하는지)
- 예상 소요 시간 (예: "약 40분 정도 걸려요")
- 추천 이유 (점수, 날씨, 최근 실행 기록 등 주어진 정보들을 함께 설명)
추천 이유를 설명할 때는 점수와 구체적인 이유를 한 문장으로 자연스럽게 함께 설명하세요:
추천 이유에 약간의 주관이 들어가도 좋아요.

예시 (점수 + 이유를 자연스럽게 결합):
- "점수가 4.44점으로 가장 높아요. 날씨가 맑고 루틴을 실행한 지 오래되어서 점수가 높게 나왔어요."
- "날씨가 맑고 루틴을 실행한 지 오래되어서 점수가 4.44점으로 가장 높아요."
- "오늘 습도가 높아서 점수가 2.13점으로 가장 높아요. 건조기를 먼저 돌리는 게 좋겠어요."

- 추천 이유에는 날씨 정보(맑음/비/습도/기온)와 최근 실행 기록(오래됨/어제/오늘)을 활용하여 점수와 함께 자연스럽게 설명하세요.
정보가 충분하지 않으면 "우선순위 점수가 가장 높아서 추천드려요."처럼 간단히 언급하거나 약간의 주관을 추가하세요.


"""
    elif is_priority_request:
        prompt = f"""
[중요 규칙]
- 본인 소개나 역할 설명은 하지 마세요. 바로 답변을 시작하세요.
- '[우선순위 추천 (점수 높은 순)]' 섹션에 나열된 루틴만 사용하세요.
- 목록에 있는 정확한 개수만큼만 추천하세요. (예: 3개면 3개, 5개면 5개)
- 사용자가 새로운 루틴을 만들거나 정보에 없는 루틴을 추가하라고 요청하면 날씨를 참고해 가전 루틴을 추천하세요.
- 각 루틴은 한 번만 언급하고, 루틴 이름과 순서는 목록에 나온 그대로 따르세요.
- 모든 숫자, 시간, 횟수, 날짜는 '[오늘의 정보]'에 있는 값만 사용하세요.
- 날씨, 온도, 습도 등 요소를 이용하여 추천 이유를 설명하세요.
- 주의: '[우선순위 추천 (점수 높은 순)]' 섹션에 나열된 루틴은 이미 목표 달성 여부를 확인한 루틴입니다. 
  WEEKLY(주간) 루틴은 이번 주 목표 횟수를 달성했으면 다음 주부터, 
  MONTHLY(월간) 루틴은 이번 달 목표 횟수를 달성했으면 다음 달부터 추천되어야 합니다.
  하지만 섹션에 나열된 루틴은 이미 필터링되어 있으므로 그대로 추천하시면 됩니다.

[오늘의 정보]
{context}

[사용자 질문]
{user_message}

[우선순위 요청에 대한 답변]
위 정보를 바탕으로, '[우선순위 추천 (점수 높은 순)]' 섹션의 루틴들을 순서대로 설명해주세요.
각 루틴에 대해 다음을 포함하세요:
- 루틴 내용 (무엇을 하는지)
- 예상 소요 시간 (예: "약 40분 정도 걸려요")
- 추천 이유 (점수, 날씨, 최근 실행 기록 등 주어진 정보들을 함께 설명)

추천 이유를 설명할 때는 점수와 구체적인 이유를 한 문장으로 자연스럽게 함께 설명하세요:

예시 (점수 + 이유를 자연스럽게 결합):
- "점수가 4.44점으로 높아요. 날씨가 맑고 루틴을 실행한 지 오래되어서 점수가 높게 나왔어요."
- "날씨가 맑고 루틴을 실행한 지 오래되어서 점수가 4.44점으로 높아요."
- "점수가 2.13점으로 두 번째로 높아요. 오늘 습도가 높아서 건조기를 먼저 돌리는 게 좋겠어요."
- "오늘 습도가 높아서 점수가 2.13점으로 두 번째로 높아요."
- "점수가 1.62점으로 세 번째예요. 어제 이미 실행하셔서 점수가 낮지만, 오늘 해두시면 좋을 것 같아요."

날씨 정보(맑음/비/습도/기온)와 최근 실행 기록(오래됨/어제/오늘)을 활용하여 점수와 함께 자연스럽게 설명하세요.
가능하면 "날씨가 맑고 루틴을 실행한 지 오래되어서 점수가 높아요"처럼 한 문장으로 표현하는 것을 권장합니다.

'오늘의 정보'에 있는 날씨 정보, 최근 실행 기록 등의 실제 데이터를 활용하여 점수와 함께 자연스럽게 설명하세요.
정보가 충분하지 않으면 "우선순위 점수가 높아서 먼저 추천드려요."처럼 간단히 언급하세요.
추천 이유에 약간의 주관이 들어가도 좋아요.

"""
    else:
        # 일반 질문: Gemini가 적당히 대응
        prompt = f"""
[일반 질문에 대한 답변]
[주의사항]
- 본인 소개나 역할 설명은 하지 마세요. 사용자의 질문에 바로 답변하세요.
- '오늘의 정보'에 있는 정보를 참고할 수 있지만, 사용자의 질문에 자연스럽게 답변하는 것이 우선입니다.
- 모든 숫자, 횟수, 날짜, 시간은 '오늘의 정보'에 있는 값을 사용하세요.
- **중요: '오늘의 정보'에 날씨 정보가 포함되어 있으면 반드시 그 정보를 활용하세요. 날씨 정보가 있으면 "알 수 없다"고 답변하지 마세요.**
- 정보에 없는 내용은 지어내지 말고, 모른다고 솔직히 말씀하세요.
- 사용자의 질문이 루틴과 관련이 없어도 친절하고 도움이 되는 답변을 제공하세요.
- 중요: '[오늘 해야 할 루틴]' 섹션에 나열된 루틴은 이미 필터링된 루틴입니다.
  WEEKLY(주간) 루틴은 이번 주 목표 횟수를 달성했으면 다음 주부터, 
  MONTHLY(월간) 루틴은 이번 달 목표 횟수를 달성했으면 다음 달부터 추천되어야 합니다.
  섹션에 나열된 루틴은 이미 목표 달성 여부를 확인하여 필터링된 것이므로 그대로 추천하시면 됩니다.

[오늘의 정보]
{context}

[사용자 질문]
{user_message}

사용자의 질문에 친절하고 자연스럽게 답변해주세요. 
- 날씨 관련 질문이면 '오늘의 정보'의 '날씨 정보' 섹션을 반드시 확인하고 활용하세요. 날씨 정보가 있으면 그 정보를 바탕으로 답변하세요.
- 내일 날씨를 물어보면 '날씨 정보'에 '내일' 정보가 있으면 그 정보를 사용하세요.
- **날씨 관련 질문이 있을 때만** 날씨 정보를 바탕으로 가전 루틴(예: 스타일러, 건조기)을 추천하고 일정 추가를 제안하세요.
- 루틴 관련 질문이면 '오늘의 정보'를 활용하세요.
- **일반적인 질문(예: "오늘 할일 말해줘", "우선순위는?")에는 일정 추가 제안을 하지 마세요. 답변만 제공하세요.**

[일정 추가 제안 규칙]
- **중요: 일정 추가 제안은 다음 두 경우에만 제안하세요:**
  1. 사용자가 날씨에 대해 물어봤고, 날씨 정보를 바탕으로 가전 루틴(예: 스타일러, 건조기)을 추천할 때만
  2. 사용자가 목록에 없는 루틴 추천을 요청했을 때만 (예: "다른 루틴 추천해줘", "다른거 추천해줘")
- **그 외의 경우에는 일정 추가 제안을 하지 마세요. 일반적인 답변만 제공하세요.**
- 일정 추가 제안 시 반드시 다음 형식으로 응답하세요:
  "일정을 추가해드릴까요?"
- 일정 추가 제안이 포함된 경우, 응답 끝에 반드시 다음 JSON 형식으로 정보를 포함하세요:
  [SCHEDULE_SUGGESTION]
  {{
    "routine_name": "스타일러 가동하기",
    "routine_type": "ETC",
    "schedule_type": "DAILY",
    "preferred_time": "19:00",
    "run_minutes": 30,
    "schedule_date": "2025-12-12"
  }}
  [/SCHEDULE_SUGGESTION]
  
- **중요: [SCHEDULE_SUGGESTION] 태그와 JSON은 사용자에게 보이지 않도록 응답 텍스트의 맨 끝에만 포함하세요. 사용자가 보는 답변에는 "일정을 추가해드릴까요?" 문구만 포함하고, JSON은 별도로 숨겨진 형식으로 추가하세요.**
- routine_name: 루틴 이름 (예: "스타일러 가동하기", "건조기 돌리기")
- routine_type: 루틴 타입 ("CLEANING", "LAUNDRY", "ETC" 등)
- schedule_type: 스케줄 타입 ("DAILY", "WEEKLY", "MONTHLY")
- preferred_time: 선호 시간 (예: "19:00", "MORNING", "EVENING")
- run_minutes: 예상 소요 시간 (분 단위)
- schedule_date: 일정을 추가할 날짜 (YYYY-MM-DD 형식, 예: "2025-12-12"). 
  사용자가 언급한 날짜(예: "다음주", "내일", "12월 12일")가 있으면 그 날짜를 사용하고, 
  없으면 오늘 날짜를 사용하세요. 날짜는 반드시 YYYY-MM-DD 형식으로 제공하세요.

그밖에 일반적인 대화나 다른 질문이면 적절히 대응해주세요. 일정 추가 제안 없이 답변만 제공하세요.

"""



    try:
        response = gemini_model_instance.generate_content(prompt)
        answer = response.text

        return jsonify({
            "reply": answer,
            # 디버깅용으로 보고 싶으면 남기고, 출시 땐 context_used는 지워도 됨
            "context_used": context,
        })
    except Exception as e:
        error_msg = str(e)
        current_app.logger.exception("Gemini chat error")
        
        # 모델 이름 오류인 경우 더 친절한 메시지
        if "not found" in error_msg or "not supported" in error_msg:
            return jsonify({
                "error": "model_not_found",
                "message": f"사용된 모델({gemini_model_name})을 찾을 수 없습니다. API 키나 모델 이름을 확인해주세요.",
                "details": error_msg[:200]
            }), 500
        
        return jsonify({"error": "chat_failed", "details": error_msg[:200]}), 500
