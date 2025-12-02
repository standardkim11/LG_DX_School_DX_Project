from datetime import datetime
from sqlalchemy import Sequence
from Project.extensions import db


class Notification(db.Model):
    """알림"""
    __tablename__ = "notifications"

    id = db.Column(db.Integer, Sequence('notifications_id_seq', start=1), primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    routine_id = db.Column(
        db.Integer,
        db.ForeignKey("routines.id"),
        nullable=True,
    )

    status = db.Column(db.String(20), nullable=False, default="PENDING")
    title = db.Column(db.String(200), nullable=False)
    message = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<Notification {self.title} ({self.status})>"

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "routine_id": self.routine_id,
            "status": self.status,
            "title": self.title,
            "message": self.message,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
