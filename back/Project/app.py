import sys, os
import subprocess
from pathlib import Path

# Add project root to Python path so imports work from any directory
project_root = Path(__file__).parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

# ============================================================
#  🔹 0) requirements.txt 자동 설치 체크
# ============================================================
def check_and_install_requirements():
    """requirements.txt가 있으면 필요한 패키지가 설치되어 있는지 확인하고 없으면 설치"""
    requirements_path = project_root / "requirements.txt"
    
    if not requirements_path.exists():
        print("[INFO] requirements.txt 파일을 찾을 수 없습니다.")
        return
    
    print("[INFO] requirements.txt 확인 중...")
    
    # pip list로 설치된 패키지 확인
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "list", "--format=freeze"],
            capture_output=True,
            text=True,
            check=True
        )
        installed_packages = {line.split("==")[0].lower() for line in result.stdout.splitlines() if "==" in line}
    except subprocess.CalledProcessError:
        installed_packages = set()
    
    # requirements.txt 읽기
    with open(requirements_path, "r", encoding="utf-8") as f:
        required_packages = []
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                # 패키지 이름 추출 (예: "Flask>=2.0.0" -> "flask")
                package_name = line.split(">=")[0].split("==")[0].split("<")[0].split(">")[0].strip().lower()
                if package_name and package_name not in installed_packages:
                    required_packages.append(line)
    
    if required_packages:
        print(f"[INFO] {len(required_packages)}개의 패키지가 누락되었습니다. 자동 설치를 시작합니다...")
        try:
            subprocess.run(
                [sys.executable, "-m", "pip", "install", "-r", str(requirements_path)],
                check=True
            )
            print("[OK] requirements.txt 패키지 설치 완료")
        except subprocess.CalledProcessError as e:
            print(f"[WARNING] 패키지 설치 중 오류 발생: {e}")
            print("[WARNING] 수동으로 'pip install -r requirements.txt'를 실행해주세요.")
    else:
        print("[OK] 모든 필수 패키지가 설치되어 있습니다.")

# 서버 시작 전에 requirements 체크 (import 전에 실행)
check_and_install_requirements()

import oracledb
import joblib  # type: ignore
from urllib.parse import quote_plus
from flask import Flask
from dotenv import load_dotenv  # ← 추가: .env 로드

from Project.extensions import db, cors
from routes.routine_routes import routine_bp
from routes.notification_routes import notification_bp
from routes.recommend_routes import recommend_bp  # type: ignore
from routes.chat_routes import chat_bp
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
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
# ============================================================
#  🔹 3) Oracle Instant Client 초기화
# ============================================================
try:
    oracledb.init_oracle_client(lib_dir=INSTANT_CLIENT_DIR)
    print("[OK] Oracle Client initialized in THICK mode")
except Exception as e:
    print("\n" + "="*60)
    print("[ERROR] Oracle Instant Client를 찾을 수 없습니다!")
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

    # CORS 헤더 명시적 설정 (추가 보안)
    @app.after_request
    def after_request(response):
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept')
        response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH')
        return response


    # ============================================================
    #  🔹 DB 테이블 생성
    # ============================================================
    with app.app_context():
        try:
            db.create_all()
            print("[OK] Database tables created successfully")
        except Exception as e:
            print(f"[WARNING] Could not create tables: {e}")

    # ============================================================
    #  🔹 ML 모델 로딩
    # ============================================================
    try:
        model_dir = os.path.join(project_root, "ML_model")
        model_path = os.path.join(model_dir, "priority_xgb_model.pkl")
        feature_path = os.path.join(model_dir, "priority_feature_cols.pkl")

        app.model = joblib.load(model_path)  # type: ignore
        app.feature_cols = joblib.load(feature_path)  # type: ignore

        print("[OK] XGBoost 모델 및 feature 리스트 로딩 완료")
    except Exception as e:
        app.model = None  # type: ignore
        app.feature_cols = None  # type: ignore
        print(f"[WARNING] Could not load ML model: {e}")

    # ============================================================
    #  🔹 Blueprint 등록
    # ============================================================
    app.register_blueprint(routine_bp)
    app.register_blueprint(notification_bp, url_prefix="/api")
    app.register_blueprint(recommend_bp,    url_prefix="/api/recommend")
    app.register_blueprint(voice_bp,        url_prefix="/api")
    app.register_blueprint(chat_bp, url_prefix="/api/chat")
    # 디버깅: 등록된 모든 라우트 출력
    if app.debug:
        print("\n" + "="*60)
        print("[INFO] 등록된 라우트 목록:")
        print("="*60)
        for rule in app.url_map.iter_rules():
            print(f"  {rule.methods} {rule.rule}")
        print("="*60 + "\n")

    return app

#print(">>> DB_USER:", repr(DB_USER))
#print(">>> DB_PASSWORD:", repr(DB_PASSWORD))
#print(">>> EZCONNECT_DSN:", repr(EZCONNECT_DSN))

# ============================================================
#  🔹 Flask App 실행
# ============================================================
app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8088, debug=True)
