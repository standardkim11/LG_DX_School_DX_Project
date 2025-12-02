# db.py
import oracledb

# 네가 사용 중인 계정/호스트 정보로 바꿔 넣기
ORACLE_USERNAME = "LGDX"
ORACLE_PASSWORD = "12345"
ORACLE_DSN      = "localhost:1521/XEPDB1"  # 예: "localhost:1521/XEPDB1"

def get_connection():
    """Oracle DB 커넥션 하나 생성해서 반환"""
    return oracledb.connect(
        user=ORACLE_USERNAME,
        password=ORACLE_PASSWORD,
        dsn=ORACLE_DSN
    )
