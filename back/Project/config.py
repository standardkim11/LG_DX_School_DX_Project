import os
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

# Oracle DB 접속 정보
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
EZCONNECT_DSN = os.getenv("DB_DSN")  # "host:port/service_name"

# Instant Client 경로 (선택)
ORACLE_CLIENT_PATH = os.getenv("ORACLE_CLIENT_PATH")

# Flask secret key
SECRET_KEY = os.getenv("SECRET_KEY", "default_secret_key")
