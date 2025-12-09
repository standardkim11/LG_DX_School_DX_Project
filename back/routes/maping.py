from datetime import datetime, date
from models import Routine, RoutineExecution
from sqlalchemy import or_
from Project.extensions import db
import re
# =========================
# 공통 코드 매핑 및 인코더
# =========================

def get_korean_object_particle(word: str) -> str:
    """
    한국어 단어의 마지막 글자를 확인하여 '을' 또는 '를'을 반환
    받침이 있으면 '을', 없으면 '를'
    """
    if not word:
        return "를"
    
    # 마지막 글자 가져오기
    last_char = word[-1]
    
    # 한글 유니코드 범위: 0xAC00 ~ 0xD7A3
    char_code = ord(last_char)
    if 0xAC00 <= char_code <= 0xD7A3:
        # (유니코드 - 0xAC00) % 28이 0이 아니면 받침이 있음
        has_final_consonant = (char_code - 0xAC00) % 28 != 0
        return "을" if has_final_consonant else "를"
    else:
        # 한글이 아니면 기본값으로 "를" 사용
        return "를"


# ROUTINE_TYPE 코드
# 0: CLEANING, 1: LAUNDRY, 2 : , 3 : ,4: ETC
ROUTINE_TYPE_MAP = {
    # 0: 청소
    "청소": 0, "바닥청소": 0, "cleaning": 0, "치우기": 0,

    # 1: 빨래
    "빨래": 1, "세탁": 1, "laundry": 1, "빨래하기": 1, "세탁기 돌리기": 1,

    # 2: 설거지
    "설거지": 2, "설거지하기": 2, "washing": 2, "dishwashing": 2,

    # 3: 분리수거
    "분리수거": 3, "분리수거하기": 3, "쓰레기버리기": 3, 
    "separating": 3, "버리기": 3,

    # 4: 기타
    "기타": 4, "etc": 4
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
    """사용자 입력을 ROUTINE_TYPE 코드(0~4)로 변환한다."""
    
    # 숫자면 그대로 반환 (0~4)
    if isinstance(value, (int, float)):
        return int(value)
    
    # None -> 기타
    if value is None:
        return 4

    # 문자열 정규화
    key = str(value).replace(" ", "")        # 공백 제거
    key_lower = key.lower()                  # 대소문자 통일

    # 매핑에 존재할 경우 → 정해진 코드 반환
    if key_lower in ROUTINE_TYPE_MAP:
        return ROUTINE_TYPE_MAP[key_lower]

    # ★ 그 외 모든 입력은 자동으로 '기타(4)' 처리 ★
    return 4


def detect_routine_type_from_name(name: str) -> str:
    """
    루틴 이름에서 루틴 타입을 자동으로 감지하여 문자열로 반환.
    Returns: "CLEANING", "LAUNDRY", "WASHING", "SEPARATING", "ETC"
    """
    if not name:
        return "ETC"
    
    # 루틴 이름 정규화 (시간대 제거)
    normalized = normalize_routine_name(name)
    normalized_lower = normalized.lower().replace(" ", "")
    original_lower = name.lower().replace(" ", "")
    
    # 우선순위: 더 구체적인 키부터 확인 (긴 키부터)
    # ROUTINE_TYPE_MAP의 키들을 길이 순으로 정렬하여 긴 것부터 확인
    sorted_keys = sorted(ROUTINE_TYPE_MAP.items(), key=lambda x: len(x[0]), reverse=True)
    
    for key, code in sorted_keys:
        key_no_space = key.replace(" ", "")
        # 정규화된 이름이나 원본 이름에 키가 포함되어 있는지 확인
        if key_no_space in normalized_lower or key_no_space in original_lower:
            # 코드를 문자열로 변환
            if code == 0:
                return "CLEANING"
            elif code == 1:
                return "LAUNDRY"
            elif code == 2:
                return "WASHING"
            elif code == 3:
                return "SEPARATING"
            else:
                return "ETC"
    
    # 매칭 실패 시 기본값
    return "ETC"



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
    s = str(value).strip()
    # 원본 값으로 먼저 찾기 (한글은 소문자 변환이 의미 없으므로)
    result = WEATHER_MAP.get(s, None)
    if result is not None:
        return result
    # 소문자 변환 후 찾기
    s_lower = s.lower()
    result = WEATHER_MAP.get(s_lower, None)
    if result is not None:
        return result
    # 부분 매칭 시도 (예: "rainy" -> "rain", "비오는날" -> "비")
    for key, code in WEATHER_MAP.items():
        if key in s or s in key:
            return code
        if key in s_lower or s_lower in key:
            return code
    # 매칭 실패 시 기본값 0 (맑음) 반환
    # 디버깅을 위해 로그 출력 (하지만 maping.py는 logger가 없으므로 print 사용)
    print(f"⚠️ [encode_weather] 날씨 값 매칭 실패: '{s}' -> 기본값 0 (맑음) 반환")
    return 0

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
# RoutineExecution.status는 숫자(2=완료, 3=실패) 또는 문자열("COMPLETED", "FAILED")로 저장될 수 있음
# DB에 실제로 숫자로 저장되어 있으므로 숫자와 문자열 둘 다 처리
DONE_STATUS = 2  # 완료 상태 (숫자)
DONE_STATUS_STR = "COMPLETED"  # 완료 상태 (문자열)
FAILED_STATUS = 3  # 실패 상태 (숫자)
FAILED_STATUS_STR = "FAILED"  # 실패 상태 (문자열)

# =========================
# 역매핑 (정수 → 문자열 라벨)
# =========================

# ROUTINE_TYPE_MAP은 문자열→정수니까 반대로 뒤집어서 정수→문자열 매핑 생성
REVERSE_ROUTINE_TYPE = {v: k for k, v in ROUTINE_TYPE_MAP.items()}

# SCHEDULE_MAP 역매핑
REVERSE_SCHEDULE_TYPE = {v: k for k, v in SCHEDULE_MAP.items()}

# WEATHER 역매핑
REVERSE_WEATHER = {v: k for k, v in WEATHER_MAP.items()}

# =========================
# 루틴 유형별 기본 소요 시간 (시연용)
# =========================
DEFAULT_RUN_MINUTES_BY_TYPE = {
    "LAUNDRY": 40,    # 세탁기 돌리기
    "CLEANING": 30,   # 바닥 청소 등
    "HOUSEWORK": 25,  # 설거지/정리 같은 집안일
    "MORNING": 20,    # 아침 루틴
    "AFTER_WORK": 20, # 퇴근 후 루틴
    "ETC": 15,        # 기타
}

def get_default_run_minutes(routine_type) -> int:
    """
    루틴 타입(문자열 기준)에 따른 기본 소요 시간 반환.
    값이 없거나 알 수 없으면 30분으로 가정.
    """
    if routine_type is None:
        return 30
    # DB에 "LAUNDRY", "CLEANING" 이런 문자열로 들어가 있으니 그대로 사용
    key = str(routine_type).strip().upper()
    return DEFAULT_RUN_MINUTES_BY_TYPE.get(key, 30)

def is_scheduled_today(routine: Routine, today: date) -> bool:
    """
    ROUTINE.schedule_type 기준으로 '오늘 후보인지' 판단
    DAILY  : created_at 날짜부터 삭제할 때까지 매일 True
    WEEKLY : created_at 요일 == 오늘 요일 (단, created_at 날짜 이후여야 함)
    MONTHLY: created_at 일자 == 오늘 일자 (단, created_at부터 한 달 동안만)
    ADHOC  : 일단 항상 True (나중에 규칙 바뀌면 여기만 수정)
    """
    st = (routine.schedule_type or "").upper()
    created = routine.created_at.date() if routine.created_at else today

    # created_at 날짜 이전이면 표시하지 않음
    if today < created:
        return False

    if st == "DAILY":
        # DAILY: created_at 날짜부터 삭제할 때까지 매일 표시
        return True
    elif st == "WEEKLY":
        # WEEKLY: created_at 요일 == 오늘 요일 (단, created_at 날짜 이후)
        return created.weekday() == today.weekday()
    elif st == "MONTHLY":
        # MONTHLY: created_at부터 30일간 매일 표시
        from datetime import timedelta
        one_month_later = created + timedelta(days=30)
        return today <= one_month_later
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

    # 완료 상태만 체크 (status는 숫자로 저장됨: 2=완료). 실패는 제외하지 않음
    return (
        last_log.start_time.date() == today
        and last_log.status == 2
    )


def is_goal_achieved(routine: Routine, user_id: int, today: date) -> bool:
    """
    WEEKLY/MONTHLY 루틴의 목표 달성 여부 확인
    WEEKLY: 이번 주에 schedule_frequency 횟수만큼 완료했으면 True
    MONTHLY: created_at부터 30일간 schedule_frequency 횟수만큼 완료했으면 True
    DAILY: 항상 False (목표 달성 개념 없음)
    """
    st = (routine.schedule_type or "").upper()
    
    if st == "DAILY":
        return False  # DAILY는 목표 달성 개념 없음
    
    # schedule_frequency 가져오기 (기본값 1)
    frequency = getattr(routine, 'schedule_frequency', 1) or 1
    if frequency < 1:
        frequency = 1
    
    print(f"[is_goal_achieved] 루틴 {routine.id} ({routine.name}): schedule_type={st}, frequency={frequency}, today={today}")
    if frequency < 1:
        frequency = 1
    
    # 완료된 실행 기록 확인 (숫자 2 또는 문자열 "COMPLETED" 둘 다 처리)
    from Project.extensions import db
    from models import RoutineExecution
    from datetime import datetime, timedelta
    from sqlalchemy import func, or_
    
    if st == "WEEKLY":
        # 이번 주 시작일 계산 (월요일)
        weekday = today.weekday()  # 0=월요일, 6=일요일
        week_start = today - timedelta(days=weekday)
        week_start_dt = datetime.combine(week_start, datetime.min.time())
        week_end_dt = datetime.combine(week_start + timedelta(days=7), datetime.min.time())
        
        # 이번 주 완료 횟수 집계 (status는 숫자로 저장됨: 2=완료)
        # Oracle에서는 숫자 컬럼과 문자열 비교 시 타입 오류 발생하므로 숫자만 비교
        completed_count = db.session.query(func.count(RoutineExecution.id)).filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.routine_id == routine.id,
            RoutineExecution.start_time >= week_start_dt,
            RoutineExecution.start_time < week_end_dt,
            RoutineExecution.status == 2  # 완료 상태 (숫자)
        ).scalar() or 0
        
        return completed_count >= frequency
        
    elif st == "MONTHLY":
        # MONTHLY: created_at부터 30일간 기간 내에 frequency 횟수만큼 완료했으면 목표 달성
        created = routine.created_at.date() if routine.created_at else today
        created_dt = datetime.combine(created, datetime.min.time())
        # created_at부터 30일 후까지
        period_end = created + timedelta(days=30)
        period_end_dt = datetime.combine(period_end, datetime.min.time())
        
        # 기간 내 완료 횟수 집계 (status는 숫자로 저장됨: 2=완료)
        # Oracle에서는 숫자 컬럼과 문자열 비교 시 타입 오류 발생하므로 숫자만 비교
        completed_count = db.session.query(func.count(RoutineExecution.id)).filter(
            RoutineExecution.user_id == user_id,
            RoutineExecution.routine_id == routine.id,
            RoutineExecution.start_time >= created_dt,
            RoutineExecution.start_time < period_end_dt,
            RoutineExecution.status == 2  # 완료 상태 (숫자)
        ).scalar() or 0
        
        print(f"[is_goal_achieved] MONTHLY 루틴 {routine.id}: created={created}, period_end={period_end}, completed_count={completed_count}, frequency={frequency}, today={today}")
        
        # 목표 달성 여부 확인
        if completed_count >= frequency:
            # 목표 달성 시, 마지막 완료 날짜 확인 (status는 숫자로 저장됨: 2=완료)
            # Oracle에서는 숫자 컬럼과 문자열 비교 시 타입 오류 발생하므로 숫자만 비교
            last_completed = RoutineExecution.query.filter(
                RoutineExecution.user_id == user_id,
                RoutineExecution.routine_id == routine.id,
                RoutineExecution.start_time >= created_dt,
                RoutineExecution.start_time < period_end_dt,
                RoutineExecution.status == 2  # 완료 상태 (숫자)
            ).order_by(RoutineExecution.start_time.desc()).first()
            
            if last_completed and last_completed.start_time:
                last_completed_date = last_completed.start_time.date()
                # 마지막 완료 날짜의 다음날부터는 더 이상 표시하지 않음
                # 오늘이 마지막 완료 날짜보다 이후면 True (표시 안함)
                should_hide = today > last_completed_date
                print(f"[is_goal_achieved] MONTHLY 루틴 {routine.id}: completed_count={completed_count}, frequency={frequency}, last_completed_date={last_completed_date}, today={today}, should_hide={should_hide}")
                return should_hide
            # 완료 기록이 있지만 날짜 정보가 없으면 목표 달성으로 간주
            print(f"[is_goal_achieved] MONTHLY 루틴 {routine.id}: completed_count={completed_count}, frequency={frequency}, last_completed 정보 없음, True 반환")
            return True
        
        return False
    
    return False


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
        and last_log.status == 3  # status=3 (FAILED, 숫자)
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
