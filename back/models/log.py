from datetime import datetime
from sqlalchemy import Sequence
from Project.extensions import db


class DeviceLog(db.Model):
    """가전 사용 로그 (세탁기/에어컨/정수기 통합)"""
    __tablename__ = "device_logs"

    id = db.Column(db.Integer, Sequence('device_logs_id_seq', start=1), primary_key=True)
    serial_no = db.Column(
        db.String(100),
        db.ForeignKey("user_devices.serial_no"),
        nullable=False,
    )

    device_type = db.Column(db.String(50), nullable=False)  # washer / aircon / purifier
    start_time = db.Column(db.DateTime, nullable=False)
    end_time = db.Column(db.DateTime, nullable=True)
    run_time = db.Column(db.Integer, nullable=True)
    mode = db.Column(db.String(50), nullable=True)
    status = db.Column(db.String(20), nullable=True)

    extra_info = db.Column(db.Text, nullable=True)

    def __repr__(self):
        return f"<DeviceLog {self.device_type} {self.start_time}>"

    def to_dict(self):
        return {
            "id": self.id,
            "serial_no": self.serial_no,
            "device_type": self.device_type,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat() if self.end_time else None,
            "run_time": self.run_time,
            "mode": self.mode,
            "status": self.status,
            "extra_info": self.extra_info,
        }
