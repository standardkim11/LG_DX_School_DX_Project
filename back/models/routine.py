from datetime import datetime
from sqlalchemy import Sequence
from Project.extensions import db


class Routine(db.Model):
    """루틴 기본 정보"""
    __tablename__ = "routines"

    id = db.Column(db.Integer, Sequence('routines_id_seq', start=1), primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)

    name = db.Column(db.String(100), nullable=False)
    routine_type = db.Column(db.String(50), nullable=False)   # MORNING / AFTER_WORK ...

    serial_no = db.Column(
        db.String(100),
        db.ForeignKey("user_devices.serial_no"),
        nullable=True,
    )  # 특정 가전과 연결된 루틴

    importance = db.Column(db.Integer, nullable=True)
    run_minutes = db.Column(db.Integer, nullable=True)
    schedule_type = db.Column(db.String(20), nullable=False, default="ONCE")
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    preferred_time = db.Column(db.String(50), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    executions = db.relationship("RoutineExecution", backref="routine", lazy=True)
    notifications = db.relationship("Notification", backref="routine", lazy=True)

    def __repr__(self):
        return f"<Routine {self.name} ({self.routine_type})>"

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "name": self.name,
            "routine_type": self.routine_type,
            "serial_no": self.serial_no,
            "importance": self.importance,
            "run_minutes": self.run_minutes,
            "schedule_type": self.schedule_type,
            "is_active": self.is_active,
            "preferred_time": self.preferred_time.isoformat()
            if self.preferred_time
            else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class RoutineExecution(db.Model):
    """루틴 수행 로그"""
    __tablename__ = "routine_executions"

    id = db.Column(db.Integer, Sequence('routine_executions_id_seq', start=1), primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    routine_id = db.Column(db.Integer, db.ForeignKey("routines.id"), nullable=False)

    status = db.Column(db.String(20), nullable=False)  # COMPLETED / SKIPPED / ...
    start_time = db.Column(db.DateTime, nullable=False)
    end_time = db.Column(db.DateTime, nullable=True)
    run_time = db.Column(db.Integer, nullable=True)

    recommended_flag = db.Column(db.Boolean, nullable=False, default=False)
    priority_score = db.Column(db.Float, nullable=True)

    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<RoutineExecution routine={self.routine_id} status={self.status}>"

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "routine_id": self.routine_id,
            "status": self.status,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat() if self.end_time else None,
            "run_time": self.run_time,
            "recommended_flag": self.recommended_flag,
            "priority_score": self.priority_score,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
