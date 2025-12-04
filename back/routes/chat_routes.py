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


def build_context_for_user(user_id: int) -> str:
    """
    우리 서비스 DB를 조회해서,
    - 오늘 해야 할 루틴 리스트 (완료되지 않고 실패하지 않은 루틴만)
    - 이번 주 세탁기 완료 횟수
    를 텍스트로 정리해서 반환.
    """
    today = date.today()

    # === 오늘 루틴 ===
    routines = Routine.query.filter_by(user_id=user_id, is_active=True).all()
    today_items: list[str] = []
    today_routine_ids = []  # 디버깅용
    
    # 디버깅: 필터링 과정 확인
    total_routines = len(routines)
    scheduled_count = 0
    done_count = 0
    failed_count = 0
    included_count = 0

    for r in routines:
        if not is_scheduled_today(r, today):
            continue
        scheduled_count += 1
        
        # 각 루틴의 최근 실행 기록 확인
        last_log = (
            RoutineExecution.query
            .filter_by(user_id=user_id, routine_id=r.id)
            .order_by(RoutineExecution.start_time.desc())
            .first()
        )
        
        if last_log and last_log.start_time:
            log_date = last_log.start_time.date()
            log_status = last_log.status
            current_app.logger.info(
                f"[CHAT build_context] Routine {r.id} ({r.name}): "
                f"last_log date={log_date}, status={log_status}, today={today}"
            )
        
        if is_done_today(r, user_id, today):
            done_count += 1
            continue
        if is_failed_today(r, user_id, today):
            failed_count += 1
            continue

        # 원본 이름과 정규화된 이름 모두 로깅
        original_name = r.name or ""
        normalized_name = normalize_routine_name(original_name)
        
        name = normalized_name
        minutes = r.run_minutes or 0
        today_items.append(f"- {name} (예상 {minutes}분)")
        today_routine_ids.append(r.id)  # 디버깅용
        included_count += 1

    if not today_items:
        today_text = "오늘 스케줄된 루틴은 없습니다."
    else:
        today_text = "\n".join(today_items)
    
    # 디버깅 로그
    current_app.logger.info(
        f"[CHAT build_context] 필터링 결과: "
        f"전체={total_routines}, 오늘스케줄={scheduled_count}, "
        f"완료={done_count}, 실패={failed_count}, 포함={included_count}"
    )

    # === 이번 주 세탁기 실행 횟수 ===
    # 기준: 월요일~오늘까지, status=2(DONE), routine_type=LAUNDRY
    start_of_week = today - timedelta(days=today.weekday())
    start_dt = datetime.combine(start_of_week, time.min)
    end_dt = datetime.combine(today, time.max)

    laundry_count = (
        RoutineExecution.query
        .join(Routine, RoutineExecution.routine_id == Routine.id)
        .filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.start_time >= start_dt,
            RoutineExecution.start_time <= end_dt,
            Routine.routine_type.in_(["LAUNDRY", "세탁", "빨래"]),
            RoutineExecution.status == 2,       # DONE
        )
        .count()
    )

    ctx_lines = [
        f"오늘 날짜: {today.isoformat()}",
        "",
        "[오늘 해야 할 루틴]",
        today_text,
        "",
        f"[이번 주 세탁기 완료 횟수] {laundry_count}회",
    ]
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

    if not user_message:
        return jsonify({"error": "message is required"}), 400

    # 1) 우선순위 추천 관련 키워드 감지
    priority_keywords = ["우선순위", "중요한 순위", "어떤 순서", "순서대로", "뭐부터", "먼저 해야 할", "우선적으로"]
    is_priority_request = any(keyword in user_message for keyword in priority_keywords)

    priority_data = None
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
                        if not is_scheduled_today(r, today):
                            continue
                        if is_done_today(r, user_id, today):
                            continue
                        if is_failed_today(r, user_id, today):
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
    # 우선순위 요청인 경우: 우선순위 정보만 포함 (중복 방지)
    # 일반 요청인 경우: 전체 컨텍스트 포함
    
    if is_priority_request and priority_data and isinstance(priority_data, list) and len(priority_data) > 0:
        # 우선순위 요청: 우선순위 섹션만 사용
        today = date.today()
        context_lines = [
            f"오늘 날짜: {today.isoformat()}",
            "",
            "[우선순위 추천 (점수 높은 순)]",
        ]
        for idx, item in enumerate(priority_data, 1):
            score = item.get('pred_priority_score', 0)
            name = item.get('routine_name', '알 수 없음')
            minutes = item.get('run_minutes', 30)
            context_lines.append(f"{idx}. {name} (점수: {score:.2f}, 예상 {minutes}분)")
        
        # 이번 주 세탁기 완료 횟수 추가
        try:
            from models import WeatherInfo
            start_of_week = today - timedelta(days=today.weekday())
            start_dt = datetime.combine(start_of_week, time.min)
            end_dt = datetime.combine(today, time.max)
            laundry_count = (
                RoutineExecution.query
                .join(Routine, RoutineExecution.routine_id == Routine.id)
                .filter(
                    RoutineExecution.user_id == user_id,
                    RoutineExecution.start_time >= start_dt,
                    RoutineExecution.start_time <= end_dt,
                    Routine.routine_type.in_(["LAUNDRY", "세탁", "빨래"]),
                    RoutineExecution.status == 2,
                )
                .count()
            )
            context_lines.append("")
            context_lines.append(f"[이번 주 세탁기 완료 횟수] {laundry_count}회")
        except Exception as e:
            current_app.logger.exception("세탁기 횟수 조회 오류")
        
        context = "\n".join(context_lines)
        
        # 디버깅
        current_app.logger.info(f"[CHAT] 우선순위 모드: {len(priority_data)}개 루틴만 전달")
        current_app.logger.info(f"[CHAT] 우선순위 루틴 IDs: {[item.get('routine_id') for item in priority_data]}")
    else:
        # 일반 요청: 전체 컨텍스트
        try:
            context = build_context_for_user(user_id)
        except Exception as e:
            current_app.logger.exception("build_context_for_user error")
            context = "오늘의 루틴/기록 정보를 불러오지 못했습니다."
    
    # 디버깅: 최종 컨텍스트 확인
    current_app.logger.info(f"[CHAT] 최종 컨텍스트 길이: {len(context)} 문자")
    current_app.logger.info(f"[CHAT] 최종 컨텍스트 (처음 500자): {context[:500]}")

    # 4) Gemini에 넘길 프롬프트 구성
    if is_priority_request:
        prompt = f"""
너는 사용자의 생활 루틴과 가전 사용을 도와주는 한국어 어시스턴트야.

[절대 규칙 - 반드시 지켜야 함]
1. '[우선순위 추천 (점수 높은 순)]' 섹션에 나열된 루틴만 사용해라.
2. 정확히 그 목록에 적힌 루틴 개수만큼만 추천해라. (예: 3개면 정확히 3개만)
3. 새로운 루틴을 만들어내거나 추가하지 마라. 정보에 없는 루틴은 절대 언급하지 마라.
4. 각 루틴은 한 번씩만 언급해라. 같은 루틴을 여러 번 반복하지 마라.
5. 루틴 이름은 정확히 '[우선순위 추천]'에 나온 이름 그대로 사용해라.
6. 순서는 '[우선순위 추천]'에 나온 순서 그대로 따라라 (1번이 가장 먼저, 마지막 번호가 마지막).

[오늘의 정보]
{context}

[사용자 질문]
{user_message}

위 정보를 바탕으로, '[우선순위 추천]' 섹션에 나온 루틴들을 순서대로 설명해줘.
각 루틴의 예상 시간도 함께 언급하고, 마지막에 '참고로, 이번 주 세탁기 완료 횟수는 X회입니다.'를 추가해줘.
"""
    else:
        prompt = f"""
너는 사용자의 생활 루틴과 가전 사용을 도와주는 한국어 어시스턴트야.
주어진 '오늘의 정보'를 최대한 활용해서 사용자의 질문에 자연스럽게 답변해줘.
숫자나 횟수는 정보에 있는 값만 사용하고, 모르는 건 모른다고 말해.

[오늘의 정보]
{context}

[사용자 질문]
{user_message}
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
