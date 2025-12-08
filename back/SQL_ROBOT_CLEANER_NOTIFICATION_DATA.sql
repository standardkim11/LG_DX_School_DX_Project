-- ============================================
-- 로봇청소기 알림 테스트 데이터 추가
-- ============================================
-- care_screen 알림 테스트를 위한 데이터
-- 로봇청소기 루틴의 preferred_time이 지났는데 오늘 실행되지 않은 경우 알림 표시

-- ============================================
-- 1. 로봇청소기 루틴 확인 및 생성
-- ============================================
-- 기존에 "로봇청소기" 관련 루틴이 없으면 새로 생성
-- preferred_time을 현재 시간보다 1시간 전으로 설정 (예: 현재 15시면 14:00)

INSERT INTO routines (id, user_id, name, routine_type, run_minutes, schedule_type, schedule_frequency, is_active, preferred_time, created_at)
SELECT 
    (SELECT NVL(MAX(id), 0) + 1 FROM routines),
    1,  -- user_id
    '로봇청소기 물청소하기',  -- name
    'CLEANING',  -- routine_type
    60,  -- run_minutes (60분)
    'DAILY',  -- schedule_type
    1,  -- schedule_frequency
    1,  -- is_active
    -- 현재 시간에서 1시간 전 (예: 현재 15시면 14:00)
    TO_CHAR(SYSDATE - (1/24), 'HH24:MI'),  -- preferred_time (현재 시간 - 1시간)
    SYSDATE  -- created_at
FROM dual
WHERE NOT EXISTS (
    SELECT 1 FROM routines
    WHERE user_id = 1 
      AND is_active = 1
      AND (UPPER(name) LIKE '%로봇청소기%' OR UPPER(name) LIKE '%ROBOT%' OR UPPER(name) LIKE '%청소기%' OR UPPER(name) LIKE '%CLEANER%')
);

COMMIT;

-- ============================================
-- 2. 확인 쿼리
-- ============================================
-- 추가된/확인된 루틴 확인

SELECT 
    id, 
    name, 
    routine_type, 
    schedule_type, 
    preferred_time,
    is_active, 
    created_at,
    -- preferred_time과 현재 시간 비교
    CASE 
        WHEN preferred_time IS NOT NULL THEN
            CASE 
                -- preferred_time이 지났는지 확인 (현재 시간 > preferred_time)
                WHEN TO_DATE(TO_CHAR(SYSDATE, 'YYYY-MM-DD') || ' ' || preferred_time, 'YYYY-MM-DD HH24:MI') < SYSDATE 
                THEN '시간이 지남 (알림 표시됨)'
                ELSE '시간이 아직 안 지남 (알림 안 표시됨)'
            END
        ELSE 'preferred_time 없음'
    END as notification_status
FROM routines
WHERE user_id = 1
  AND is_active = 1
  AND (UPPER(name) LIKE '%로봇청소기%' OR UPPER(name) LIKE '%ROBOT%' OR UPPER(name) LIKE '%청소기%' OR UPPER(name) LIKE '%CLEANER%')
ORDER BY id DESC;

-- 오늘 실행 기록 확인 (없어야 알림이 표시됨)
SELECT 
    re.id, 
    re.routine_id, 
    r.name as routine_name, 
    re.status, 
    re.start_time, 
    re.end_time,
    TO_CHAR(re.start_time, 'YYYY-MM-DD') as execution_date
FROM routine_executions re
JOIN routines r ON re.routine_id = r.id
WHERE re.user_id = 1
  AND r.user_id = 1
  AND (UPPER(r.name) LIKE '%로봇청소기%' OR UPPER(r.name) LIKE '%ROBOT%' OR UPPER(r.name) LIKE '%청소기%' OR UPPER(r.name) LIKE '%CLEANER%')
  AND TRUNC(re.start_time) = TRUNC(SYSDATE)  -- 오늘 실행 기록
ORDER BY re.start_time DESC;

-- ============================================
-- 3. preferred_time 수동 설정 (선택사항)
-- ============================================
-- 알림이 바로 표시되도록 preferred_time을 현재 시간보다 과거로 설정
-- 예: 현재 15시면 14:00 또는 13:00으로 설정

/*
UPDATE routines
SET preferred_time = TO_CHAR(SYSDATE - (2/24), 'HH24:MI')  -- 현재 시간 - 2시간
WHERE user_id = 1
  AND is_active = 1
  AND (UPPER(name) LIKE '%로봇청소기%' OR UPPER(name) LIKE '%ROBOT%' OR UPPER(name) LIKE '%청소기%' OR UPPER(name) LIKE '%CLEANER%');

COMMIT;
*/

-- ============================================
-- 4. 테스트 후 정리 (필요시)
-- ============================================
-- 오늘 추가한 테스트 실행 기록 삭제

/*
DELETE FROM routine_executions
WHERE user_id = 1
  AND routine_id IN (
    SELECT id FROM routines
    WHERE user_id = 1
      AND (UPPER(name) LIKE '%로봇청소기%' OR UPPER(name) LIKE '%ROBOT%' OR UPPER(name) LIKE '%청소기%' OR UPPER(name) LIKE '%CLEANER%')
  )
  AND TRUNC(start_time) = TRUNC(SYSDATE);  -- 오늘 실행 기록만 삭제
COMMIT;
*/
