# utils.py
import math
from datetime import datetime, date

from flask import jsonify
from Project.extensions import db  # 네가 쓰는 db 객체 경로에 맞게 수정


# =========================
# 1. 위치/거리 관련 유틸
# =========================

def distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """
    두 좌표(위도/경도) 사이의 대략적인 거리(km)를 계산.
    - 입력: 위도/경도 (degrees)
    - 반환: 거리 (km)
    """
    R = 6371.0  # 지구 반지름 (km)

    rad_lat1 = math.radians(lat1)
    rad_lng1 = math.radians(lng1)
    rad_lat2 = math.radians(lat2)
    rad_lng2 = math.radians(lng2)

    dlat = rad_lat2 - rad_lat1
    dlng = rad_lng2 - rad_lng1

    a = math.sin(dlat / 2) ** 2 + math.cos(rad_lat1) * math.cos(rad_lat2) * math.sin(dlng / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c


# =========================
# 2. 날짜/시간 유틸
# =========================

def today_date() -> date:
    """서버 기준 오늘 날짜 (date 객체)"""
    return datetime.now().date()


def now_utc() -> datetime:
    """현재 시각(UTC 기준으로 저장하고 싶을 때 사용)"""
    # 필요에 따라 timezone-aware로 바꿔도 됨
    return datetime.utcnow()


# =========================
# 3. DB / 응답 헬퍼 (선택)
# =========================

def safe_commit():
    """
    db.session.commit()을 감싸는 헬퍼.
    실패 시 rollback 하고 False 반환.
    """
    try:
        db.session.commit()
        return True
    except Exception:
        db.session.rollback()
        raise  # 필요하면 여기서 로깅 후 다시 raise 해도 됨


def error_response(message: str, status_code: int = 400):
    """
    에러 응답을 통일된 형태로 반환.
    """
    response = jsonify({"status": "error", "message": message})
    response.status_code = status_code
    return response
