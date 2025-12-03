from datetime import datetime, date
from models import Routine, RoutineExecution
import re
# =========================
# 공통 코드 매핑 및 인코더
# =========================


# ROUTINE_TYPE 코드
# 0: MORNING, 1: AFTER_WORK, 2: CLEANING, 3: LAUNDRY, 4: HOUSEWORK, 5: ETC
ROUTINE_TYPE_MAP = {
    "아침": 0, "모닝": 0, "morning": 0, "MORNING": 0,
    "퇴근": 1, "퇴근후": 1, "저녁": 1, "afterwork": 1, "AFTER_WORK": 1,
    "청소": 2, "바닥청소": 2, "cleaning": 2, "CLEANING": 2,
    "빨래": 3, "세탁": 3, "laundry": 3, "LAUNDRY": 3,
    "기타": 4, "etc": 4, "ETC": 4
}

# SCHEDULE_TYPE 코드
# 0: ADHOC, 1: DAILY, 2: WEEKLY, 3: MONTHLY, 4: CUSTOM
SCHEDULE_MAP = {
    # irregular
    "비정기": 0, "adhoc": 0, "ad-hoc": 0, "irregular": 0, "ADHOC": 0,

    # daily
    "일일": 1, "매일": 1, "daily": 1, "DAILY": 1,

    # weekly
    "주간": 2, "매주": 2, "weekly": 2, "WEEKLY": 2,

    # monthly
    "월간": 3, "매월": 3, "monthly": 3, "MONTHLY": 3,

    # custom
    "커스텀": 4, "사용자정의": 4, "custom": 4, "CUSTOM": 4,
}

# WEATHER 코드
# 0: 맑음, 1: 흐림, 2: 비, 3: 눈
WEATHER_MAP = {
    "맑음": 0, "clear": 0,
    "흐림": 1, "구름": 1, "cloudy": 1,
    "비": 2, "rain": 2,
    "눈": 3, "snow": 3,
}

# 시간대(PREFERRED_TIME) 대표 시(hour) 매핑
PREFERRED_TIME_MAP = {
    "새벽": 6,
    "아침": 8,
    "오전": 10,
    "점심": 12,
    "오후": 15,
    "저녁": 19,
    "밤": 21,
    "취침전": 23,
    "퇴근후": 19,

    # 영어 표현
    "morning": 8,
    "lunch": 12,
    "afternoon": 15,
    "evening": 19,
    "night": 21,    

    "MORNING": 8,
    "LUNCH": 12,
    "AFTERNOON": 15,
    "EVENING": 19,
    "NIGHT": 21

}

FAILED_STATUS = 3

def encode_routine_type(value) -> int:
    """DB 값이 숫자이든 문자열이든 ROUTINE_TYPE 정수 코드로 변환"""
    if isinstance(value, (int, float)):
        return int(value)
    if value is None:
        return 4
    key = str(value).replace(" ", "")        # '퇴근 후' -> '퇴근후'
    key_lower = key.lower()
    if key_lower in ROUTINE_TYPE_MAP:
        return ROUTINE_TYPE_MAP[key_lower]
    if key in ROUTINE_TYPE_MAP:
        return ROUTINE_TYPE_MAP[key]
    return 4  # 기타

def encode_schedule_type(value) -> int:
    """DB 값이 숫자이든 문자열이든 SCHEDULE_TYPE 정수 코드로 변환"""
    if isinstance(value, (int, float)):
        return int(value)
    if value is None:
        return 0
    key = str(value).replace(" ", "")
    key_lower = key.lower()
    if key_lower in SCHEDULE_MAP:
        return SCHEDULE_MAP[key_lower]
    if key in SCHEDULE_MAP:
        return SCHEDULE_MAP[key]
    return 0  # ADHOC 기본

def encode_weather(value) -> int:
    """DB 값이 숫자이든 문자열이든 WEATHER 정수 코드로 변환"""
    if isinstance(value, (int, float)):
        return int(value)
    if value is None:
        return 0
    s = str(value).strip().lower()
    return WEATHER_MAP.get(s, 0)

def parse_preferred_time(value) -> int:
    """
    입력: DB에서 들어오는 preferred_time 값
         (숫자, 문자열, HH:MM, '아침', '저녁', '오후3시', None 등)
    출력: 0~23 사이 정수 hour
    """

    # 1) None → 기본값 9시
    if value is None:
        return 9

    # 2) 숫자 타입이면 바로 hour로
    if isinstance(value, (int, float)):
        h = int(value)
        return min(max(h, 0), 23)

    s = str(value).strip()

    # 3) HH:MM 형태
    if ":" in s:
        try:
            h = int(s.split(":")[0])
            return min(max(h, 0), 23)
        except Exception:
            pass

    # 4) "오전/오후 n시" 형태
    if "오전" in s or "오후" in s:
        nums = re.findall(r"\d+", s)
        if nums:
            h = int(nums[0])
            if "오후" in s and h < 12:
                h += 12
            return min(max(h, 0), 23)

    # 5) "아침", "저녁", "퇴근 후" 같은 카테고리 매핑
    key = s.replace(" ", "")  # '퇴근 후' → '퇴근후'
    if key in PREFERRED_TIME_MAP:
        return PREFERRED_TIME_MAP[key]

    key_lower = key.lower()
    if key_lower in PREFERRED_TIME_MAP:
        return PREFERRED_TIME_MAP[key_lower]

    # 6) 숫자 문자열 ("8", "17")
    if s.isdigit():
        h = int(s)
        return min(max(h, 0), 23)

    # 7) 전부 실패 → 기본값 9시
    return 9

# ======================
# 오늘 후보 필터링 로직
# ======================

# status 값은 너희 ENUM 규칙에 맞게 조정해도 됨
DONE_STATUS = 2  # 예: 0=PENDING, 1=RUNNING, 2=DONE
FAILED_STATUS = 3  # 실패

# =========================
# 역매핑 (정수 → 문자열 라벨)
# =========================

# ROUTINE_TYPE_MAP은 문자열→정수니까 반대로 뒤집어서 정수→문자열 매핑 생성
REVERSE_ROUTINE_TYPE = {v: k for k, v in ROUTINE_TYPE_MAP.items()}

# SCHEDULE_MAP 역매핑
REVERSE_SCHEDULE_TYPE = {v: k for k, v in SCHEDULE_MAP.items()}

# WEATHER 역매핑
REVERSE_WEATHER = {v: k for k, v in WEATHER_MAP.items()}

def is_scheduled_today(routine: Routine, today: date) -> bool:
    """
    ROUTINE.schedule_type 기준으로 '오늘 후보인지' 판단
    DAILY  : 항상 True
    WEEKLY : created_at 요일 == 오늘 요일
    MONTHLY: created_at 일자 == 오늘 일자
    ADHOC  : 일단 항상 True (나중에 규칙 바뀌면 여기만 수정)
    """
    st = (routine.schedule_type or "").upper()
    created = routine.created_at.date() if routine.created_at else today

    if st == "DAILY":
        return True
    elif st == "WEEKLY":
        return created.weekday() == today.weekday()
    elif st == "MONTHLY":
        return created.day == today.day
    elif st == "ADHOC":
        return True
    else:
        # 정의 안 된 타입이면 일단 후보로 본다
        return True


def is_done_today(routine: Routine, user_id: int, today: date) -> bool:
    """
    오늘 이미 완료된 루틴이면 True
    실패한 루틴(status=3)은 False를 반환하여 리스트에 남도록 함
    """
    last_log = (
        RoutineExecution.query
        .filter_by(user_id=user_id, routine_id=routine.id)
        .order_by(RoutineExecution.start_time.desc())
        .first()
    )
    if not last_log or not last_log.start_time:
        return False

    # 완료(status=2)만 체크. 실패(status=3)는 제외하지 않음
    return (
        last_log.start_time.date() == today
        and last_log.status == DONE_STATUS  # status=2 (DONE)만 체크
    )


def is_failed_today(routine: Routine, user_id: int, today: date) -> bool:
    """
    오늘 실패한 루틴이면 True
    추천 API에서 실패한 루틴을 제외할 때 사용
    """
    last_log = (
        RoutineExecution.query
        .filter_by(user_id=user_id, routine_id=routine.id)
        .order_by(RoutineExecution.start_time.desc())
        .first()
    )
    if not last_log or not last_log.start_time:
        return False

    return (
        last_log.start_time.date() == today
        and last_log.status == FAILED_STATUS  # status=3 (FAILED)
    )


# ======================
# 루틴 이름 정리 유틸
# ======================

TIME_PREFIX_PATTERN = re.compile(
    r"^(아침에|아침|점심에|점심|저녁에|저녁|오전에|오후에|오후|"
    r"퇴근\s*후|퇴근후|퇴근하고|자기\s*전|자기전|잠자기\s*전)\s*"
)

def normalize_routine_name(name: str) -> str:
    """
    루틴 이름에서 시간대/수식어(아침, 저녁, 퇴근 후, 자기 전 등)를 앞부분에서 제거하고
    행동(core action)만 남긴다.
    예) '아침 세탁기 돌리기' -> '세탁기 돌리기'
        '저녁에 분리수거하기' -> '분리수거하기'
    """
    if not name:
        return name

    original = name.strip()
    cleaned = TIME_PREFIX_PATTERN.sub("", original).strip()

    # 혹시 다 지워져버리면 원래 이름을 그대로 쓰기
    if not cleaned:
        return original

    return cleaned
