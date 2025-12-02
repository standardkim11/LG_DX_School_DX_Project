import sys, os
from pathlib import Path

# Add project root to Python path so imports work from any directory
project_root = Path(__file__).parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

import oracledb
import joblib  # type: ignore
from urllib.parse import quote_plus
from flask import Flask
from dotenv import load_dotenv  # ← 추가: .env 로드

from Project.extensions import db, cors
from routes.routine_routes import routine_bp
from routes.notification_routes import notification_bp
from routes.recommend_routes import recommend_bp
from models.voice import voice_bp

# 모델 import (SQLAlchemy 인식용)
from models import User, UserDevice, Routine, RoutineExecution, Notification, WeatherInfo, DeviceLog

# ============================================================
#  🔹 1) .env 파일 로드
# ============================================================
env_path = Path(__file__).parent / ".env"  # back/project/.env
load_dotenv(dotenv_path=env_path)

# ============================================================
#  🔹 2) 환경변수에서 보안값 불러오기
# ============================================================
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
EZCONNECT_DSN = os.getenv("DB_DSN")
INSTANT_CLIENT_DIR = os.getenv("INSTANT_CLIENT_DIR")

# ============================================================
#  🔹 3) Oracle Instant Client 초기화
# ============================================================
try:
    oracledb.init_oracle_client(lib_dir=INSTANT_CLIENT_DIR)
    print("✓ Oracle Client initialized in THICK mode")
except Exception as e:
    print("\n" + "="*60)
    print("❌ Oracle Instant Client를 찾을 수 없습니다!")
    print("="*60)
    print(f"설정된 경로: {INSTANT_CLIENT_DIR}")
    raise  # thick 모드 필수이므로 그대로 에러 발생

# ============================================================
#  🔹 Flask Application Factory
# ============================================================
def create_app():
    app = Flask(__name__)

    # SQLAlchemy URI (실제 연결은 connect_args로 함)
    app.config["SQLALCHEMY_DATABASE_URI"] = "oracle+oracledb://"

    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
        "connect_args": {
            "dsn": EZCONNECT_DSN,
            "user": DB_USER,
            "password": DB_PASSWORD
        }
    }

    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

    # DB & CORS 초기화
    db.init_app(app)
    cors.init_app(app)

    # ============================================================
    #  🔹 DB 테이블 생성
    # ============================================================
    with app.app_context():
        try:
            db.create_all()
            print("✓ Database tables created successfully")
        except Exception as e:
            print(f"⚠ Warning: Could not create tables: {e}")

    # ============================================================
    #  🔹 ML 모델 로딩
    # ============================================================
    try:
        model_dir = os.path.join(project_root, "ML_model")
        model_path = os.path.join(model_dir, "priority_xgb_model.pkl")
        feature_path = os.path.join(model_dir, "priority_feature_cols.pkl")

        app.model = joblib.load(model_path)  # type: ignore
        app.feature_cols = joblib.load(feature_path)  # type: ignore

        print("✓ XGBoost 모델 및 feature 리스트 로딩 완료")
    except Exception as e:
        app.model = None  # type: ignore
        app.feature_cols = None  # type: ignore
        print(f"⚠ Warning: Could not load ML model: {e}")

    # ============================================================
    #  🔹 Blueprint 등록
    # ============================================================
    app.register_blueprint(routine_bp)
    app.register_blueprint(notification_bp, url_prefix="/api")
    app.register_blueprint(recommend_bp,    url_prefix="/api")
    app.register_blueprint(voice_bp,        url_prefix="/api")

    return app


# ============================================================
#  🔹 Flask App 실행
# ============================================================
app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8088, debug=True)
