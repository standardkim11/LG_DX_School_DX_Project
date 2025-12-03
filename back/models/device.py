from datetime import datetime
from Project.extensions import db


class UserDevice(db.Model):
    """회원 등록 가전 정보"""
    __tablename__ = "user_devices"

    serial_no = db.Column(db.String(100), primary_key=True)  # PK
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)

    device_type = db.Column(db.String(50), nullable=False)   # washer / aircon / purifier 등
    model_name = db.Column(db.String(100), nullable=True)
    brand = db.Column(db.String(50), nullable=True)
    registered_at = db.Column(db.DateTime, default=datetime.utcnow)

    logs = db.relationship("DeviceLog", backref="device", lazy=True)

    def __repr__(self):
        return f"<UserDevice {self.device_type} ({self.serial_no})>"

    def to_dict(self):
        return {
            "serial_no": self.serial_no,
            "user_id": self.user_id,
            "device_type": self.device_type,
            "model_name": self.model_name,
            "brand": self.brand,
            "registered_at": self.registered_at.isoformat()
            if self.registered_at
            else None,
        }
