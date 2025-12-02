from Project.extensions import db
from datetime import date
from sqlalchemy import Sequence


class WeatherInfo(db.Model):
    """외부 환경 정보 (날씨/미세먼지 등)"""
    __tablename__ = "weather_info"

    id = db.Column(db.Integer, Sequence('weather_info_id_seq', start=1), primary_key=True)
    temperature = db.Column(db.Float, nullable=True)
    humidity = db.Column(db.Float, nullable=True)
    weather = db.Column(db.String(50), nullable=True)
    date = db.Column(db.Date, nullable=True)
    pm25 = db.Column(db.Float, nullable=True)
    pm10 = db.Column(db.Float, nullable=True)

    def __repr__(self):
        return f"<WeatherInfo {self.date} {self.weather}>"

    def to_dict(self):
        return {
            "id": self.id,
            "temperature": self.temperature,
            "humidity": self.humidity,
            "weather": self.weather,
            "date": self.date.isoformat() if isinstance(self.date, date) else None,
            "pm25": self.pm25,
            "pm10": self.pm10,
        }
