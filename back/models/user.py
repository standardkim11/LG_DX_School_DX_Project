from datetime import datetime
from sqlalchemy import Sequence
from Project.extensions import db


class User(db.Model):
    """회원 정보 + 집 위치"""
    __tablename__ = "users"

    id = db.Column(db.Integer, Sequence('users_id_seq', start=1), primary_key=True)  # User ID (PK)
    email = db.Column(db.String(255), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    password = db.Column(db.String(255), nullable=True)

    # 위치/주소 정보 (집 기준)
    address = db.Column(db.String(255), nullable=True)
    home_lat = db.Column(db.Float, nullable=True)
    home_lng = db.Column(db.Float, nullable=True)

    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    routines = db.relationship("Routine", backref="user", lazy=True)
    devices = db.relationship("UserDevice", backref="user", lazy=True)
    notifications = db.relationship("Notification", backref="user", lazy=True)
    executions = db.relationship("RoutineExecution", backref="user", lazy=True)

    def __repr__(self):
        return f"<User {self.email}>"

    def to_dict(self):
        return {
            "id": self.id,
            "email": self.email,
            "name": self.name,
            "address": self.address,
            "home_lat": self.home_lat,
            "home_lng": self.home_lng,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
