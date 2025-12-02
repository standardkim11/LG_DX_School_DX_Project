from flask import Blueprint, request, jsonify
from models import Notification

notification_bp = Blueprint("notification", __name__)


@notification_bp.route("/notifications", methods=["GET"])
def get_notifications():
    """알림 목록 조회: GET /api/notifications?user_id=1"""
    user_id = request.args.get("user_id", type=int, default=1)

    query = Notification.query.filter_by(user_id=user_id)
    notifs = query.order_by(Notification.created_at.desc()).all()

    return jsonify([n.to_dict() for n in notifs])
def seed_demo_data():
    """시연용 더미 데이터"""
    from models import User, UserDevice, Routine, Notification
    from Project.extensions import db
    from datetime import datetime, time

    # 이미 유저가 있으면 더미 생성 안 함
    if User.query.first():
        return

    # 1) 유저 생성
    user = User(
        email="demo@user.com",
        name="데모 사용자",
        address="서울시 어딘가",
        home_lat=37.5665,   # 서울 시청 기준
        home_lng=126.9780,
    )
    db.session.add(user)
    db.session.commit()

    # 2) 가전 등록 1개
    washer = UserDevice(
        serial_no="WASHER-001",
        user_id=user.id,
        device_type="washer",
        model_name="LG ThinQ Washer",
        brand="LG",
    )
    db.session.add(washer)

    # 3) 루틴 2개
    morning = Routine(
        user_id=user.id,
        name="아침 준비 루틴",
        routine_type="MORNING",
        importance=5,
        run_minutes=20,
        schedule_type="DAILY",
        preferred_time=time(hour=7, minute=30),
        is_active=True,
    )

    after_work = Routine(
        user_id=user.id,
        name="퇴근 후 루틴",
        routine_type="AFTER_WORK",
        importance=4,
        run_minutes=30,
        serial_no=washer.serial_no,
        schedule_type="DAILY",
        preferred_time=time(hour=19, minute=0),
        is_active=True,
    )

    db.session.add(morning)
    db.session.add(after_work)
    db.session.commit()

    # 4) 알림 하나 생성
    notif = Notification(
        user_id=user.id,
        routine_id=after_work.id,
        status="PENDING",
        title="퇴근 루틴 추천",
        message="집에 도착하면 세탁기 먼저 돌리는 것을 추천드려요!",
        created_at=datetime.utcnow(),
    )
    db.session.add(notif)

    db.session.commit()

    print("🌱 Demo data seeded!")
