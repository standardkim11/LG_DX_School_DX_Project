from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS

db = SQLAlchemy()
# CORS 설정: 모든 origin 허용 (개발 환경용)
cors = CORS(
    resources={r"/api/*": {"origins": "*"}},
    allow_headers=["Content-Type", "Authorization"],
    methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"]
)