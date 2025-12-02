# models/voice.py
from flask import Blueprint, request, jsonify
from Project.db import get_connection

voice_bp = Blueprint("voice", __name__)

@voice_bp.route("/voice/log", methods=["POST"])
def save_voice_log():
    """
    음성 인식 결과를 저장하는 API
    body 예시:
    {
      "user_id": 1,
      "raw_text": "내일 아침 7시에 세탁 루틴 추가해줘",
      "intent_type": "ROUTINE_CREATE"
    }
    """
    data = request.get_json() or {}

    user_id     = data.get("user_id")
    raw_text    = data.get("raw_text")
    intent_type = data.get("intent_type", "UNKNOWN")

    if not user_id or not raw_text:
        return jsonify({"error": "user_id와 raw_text는 필수입니다."}), 400

    conn = get_connection()
    cur = conn.cursor()

    # VOICE_SEQ로 VOICE_ID 생성
    cur.execute("SELECT VOICE_SEQ.NEXTVAL FROM DUAL")
    voice_id_row = cur.fetchone()
    voice_id = voice_id_row[0]

    cur.execute("""
        INSERT INTO VOICE_LOG
        (VOICE_ID, USER_ID, RAW_TEXT, INTENT_TYPE, STATUS)
        VALUES (:voice_id, :user_id, :raw_text, :intent_type, :status)
    """, {
        "voice_id": voice_id,
        "user_id": user_id,
        "raw_text": raw_text,
        "intent_type": intent_type,
        "status": "SUCCESS"
    })

    conn.commit()
    cur.close()
    conn.close()

    # 나중에 루틴/일정 만들 때 이 voice_id를 같이 보내면 됨
    return jsonify({"message": "ok", "voice_id": voice_id}), 201


@voice_bp.route("/voice/log", methods=["GET"])
def list_voice_logs():
    """
    (옵션) 특정 사용자의 음성 로그 조회
    /api/voice/log?user_id=1
    """
    user_id = request.args.get("user_id", type=int)

    conn = get_connection()
    cur = conn.cursor()

    if user_id:
        cur.execute("""
            SELECT VOICE_ID, USER_ID, CREATED_AT, RAW_TEXT, INTENT_TYPE, STATUS
            FROM VOICE_LOG
            WHERE USER_ID = :user_id
            ORDER BY CREATED_AT DESC
        """, {"user_id": user_id})
    else:
        cur.execute("""
            SELECT VOICE_ID, USER_ID, CREATED_AT, RAW_TEXT, INTENT_TYPE, STATUS
            FROM VOICE_LOG
            ORDER BY CREATED_AT DESC
        """)

    rows = cur.fetchall()
    cur.close()
    conn.close()

    result = []
    for r in rows:
        result.append({
            "voice_id":   r[0],
            "user_id":    r[1],
            "created_at": str(r[2]),
            "raw_text":   r[3],
            "intent_type": r[4],
            "status":     r[5],
        })

    return jsonify(result), 200
