from flask import Blueprint, current_app, request, jsonify
from datetime import datetime, time
import pandas as pd  # type: ignore
from Project.extensions import db
from models import User, Routine, Notification, RoutineExecution , UserDevice

recommend_bp = Blueprint("recommend", __name__)


@recommend_bp.route("/hello", methods=["GET"])
def hello():
    return jsonify({"message": "Hello from Flask modular app"})


@recommend_bp.route("/context-event", methods=["POST"])
def context_event():
    """
    상황 기반 추천 API
    POST /api/context-event
    body 예시:
    {   
      "user_id": 1,
      "context": "HOME_AFTER_WORK",
      "eta_minutes": 25
    }
    """
    data = request.get_json() or {}
    user_id = data.get("user_id", 1)
    context = data.get("context")
    eta_minutes = data.get("eta_minutes")

    if not context:
        return jsonify({"error": "context is required"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "user not found"}), 404

    # 간단한 더미 추천 로직
    if context == "HOME_AFTER_WORK":
        routine = (
            Routine.query.filter_by(
                user_id=user.id, routine_type="AFTER_WORK", is_active=True
            )
            .order_by(Routine.importance.desc().nullslast())
            .first()
        )
        base_message = "퇴근 후 루틴을 시작해볼까요?"
    elif context == "MORNING":
        routine = (
            Routine.query.filter_by(
                user_id=user.id, routine_type="MORNING", is_active=True
            )
            .order_by(Routine.importance.desc().nullslast())
            .first()
        )
        base_message = "아침 준비 루틴을 시작해볼까요?"
    else:
        routine = (
            Routine.query.filter_by(user_id=user.id, is_active=True)
            .order_by(Routine.importance.desc().nullslast())
            .first()
        )
        base_message = "지금 실행하기 좋은 루틴을 추천드릴게요."

    if not routine:
        return jsonify({"error": "no routine found for this user"}), 404

    if eta_minutes is not None:
        detail_msg = f"지금 출발하면 약 {eta_minutes}분 뒤 도착 예정이에요. 도착 직후 '{routine.name}'을(를) 하면 좋겠어요."
    else:
        detail_msg = f"지금 '{routine.name}'을(를) 시작하면 좋을 것 같아요."

    notif = Notification(
        user_id=user.id,  # type: ignore
        routine_id=routine.id,  # type: ignore
        status="PENDING",  # type: ignore
        title="루틴 추천",  # type: ignore
        message=detail_msg,  # type: ignore
    )
    db.session.add(notif)

    exec_log = RoutineExecution(
        user_id=user.id,  # type: ignore
        routine_id=routine.id,  # type: ignore
        status="RECOMMENDED",  # type: ignore
        start_time=datetime.utcnow(),  # type: ignore
        recommended_flag=True,  # type: ignore
        priority_score=float(routine.importance or 0),  # type: ignore
    )
    db.session.add(exec_log)

    db.session.commit()

    return jsonify(
        {
            "context": context,
            "eta_minutes": eta_minutes,
            "recommended_routine": routine.to_dict(),
            "notification": notif.to_dict(),
        }
    )

@recommend_bp.route("/test-model", methods=["GET"])
def test_model():
    """
    XGBoost 모델이 정상적으로 불러와지고
    predict()가 동작하는지 테스트하는 엔드포인트
    """
    model = current_app.model  # type: ignore
    feature_cols = current_app.feature_cols  # type: ignore

    if model is None:
        return jsonify({"error": "ML model not loaded"}), 500

    # 테스트용 입력 1개
    sample = {
        "ROUTINE_TYPE": 0,
        "IMPORTANCE": 4,
        "RUN_MINUTES": 30,
        "SCHEDULE_TYPE": 1,
        "IS_ACTIVE": 1,
        "PREFERRED_TIME": 20,

        "EXEC_HOUR": 19,
        "EXEC_DOW": 2,

        "RUN_TIME": 32,
        "STATUS": 1,
        "RECOMMENDED_FLAG": 1,

        "TEMPERATURE": 18.5,
        "HUMIDITY": 55.0,
        "WEATHER": 1,
        "PM25": 35.0,
        "PM10": 50.0,
    }

    df = pd.DataFrame([sample])

    # feature 순서 맞추기
    X = df[feature_cols]

    pred = float(model.predict(X)[0])

    return jsonify({
        "input": sample,
        "predicted_priority_score": pred
    })