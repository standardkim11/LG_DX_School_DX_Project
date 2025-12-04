# routes/chat_routes.py
from flask import Blueprint, request, jsonify, current_app
from datetime import datetime, date, time, timedelta
import os
import google.generativeai as genai

from models import Routine, RoutineExecution
from .maping import is_scheduled_today, normalize_routine_name

chat_bp = Blueprint("chat", __name__)

# --- Gemini 클라이언트 초기화 ---
API_KEY = os.getenv("GEMINI_API_KEY")
if API_KEY:
    genai.configure(api_key=API_KEY)
    gemini_model = genai.GenerativeModel("gemini-1.5-flash")
else:
    gemini_model = None
    # 키가 없으면 라우트에서 에러 리턴하게 처리


def build_context_for_user(user_id: int) -> str:
    """
    우리 서비스 DB를 조회해서,
    - 오늘 해야 할 루틴 리스트
    - 이번 주 세탁기 완료 횟수
    를 텍스트로 정리해서 반환.
    """
    today = date.today()

    # === 오늘 루틴 ===
    routines = Routine.query.filter_by(user_id=user_id, is_active=True).all()
    today_items: list[str] = []

    for r in routines:
        if not is_scheduled_today(r, today):
            continue

        name = normalize_routine_name(r.name or "")
        minutes = r.run_minutes or 0
        today_items.append(f"- {name} (예상 {minutes}분)")

    if not today_items:
        today_text = "오늘 스케줄된 루틴은 없습니다."
    else:
        today_text = "\n".join(today_items)

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
            Routine.routine_type == "LAUNDRY",  # 너희 DB에 맞게 문자열/코드 확인
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
    return "\n".join(ctx_lines)


@chat_bp.route("/chat", methods=["POST"])
def chat():
    """
    프론트에서 호출:
    POST /api/chat/chat  (아래 app.py 설정 기준)
    body: { "user_id": 1, "message": "오늘 뭐부터 해야 돼?" }
    """
    if gemini_model is None:
        return jsonify({
            "error": "no_gemini_api_key",
            "message": "서버에 GEMINI_API_KEY 환경변수가 설정되지 않았습니다."
        }), 500

    data = request.get_json() or {}
    user_id = data.get("user_id", 1)
    user_message = data.get("message")

    if not user_message:
        return jsonify({"error": "message is required"}), 400

    # 1) 우리 서비스 컨텍스트 만들기 (DB 조회)
    try:
        context = build_context_for_user(user_id)
    except Exception as e:
        current_app.logger.exception("build_context_for_user error")
        context = "오늘의 루틴/기록 정보를 불러오지 못했습니다."

    # 2) Gemini에 넘길 프롬프트 구성
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
        response = gemini_model.generate_content(prompt)
        answer = response.text

        return jsonify({
            "reply": answer,
            # 디버깅용으로 보고 싶으면 남기고, 출시 땐 context_used는 지워도 됨
            "context_used": context,
        })
    except Exception as e:
        current_app.logger.exception("Gemini chat error")
        return jsonify({"error": "chat_failed", "details": str(e)}), 500
