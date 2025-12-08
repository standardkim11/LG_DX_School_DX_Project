from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS

db = SQLAlchemy()
# CORS 설정: 모든 origin 허용 (개발 환경용)
cors = CORS(
    resources={r"/*": {"origins": "*"}},  # 모든 경로에 대해 CORS 허용
    allow_headers=["Content-Type", "Authorization", "Accept"],
    methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    supports_credentials=True
)