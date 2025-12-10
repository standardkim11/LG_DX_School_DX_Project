-- 건조기 알림 테스트 데이터 추가
-- care_screen에 알림이 표시되도록 건조기 루틴 추가

INSERT INTO routines (
    id, 
    user_id, 
    name, 
    routine_type, 
    run_minutes, 
    schedule_type, 
    schedule_frequency, 
    is_active, 
    preferred_time, 
    created_at
)
SELECT 
    (SELECT NVL(MAX(id), 0) + 1 FROM routines),
    1,  -- user_id
    '건조기 돌리기',  -- name (알림 조건: 이름에 "건조기" 포함)
    'LAUNDRY',  -- routine_type
    90,  -- run_minutes (건조기는 보통 90분)
    'DAILY',  -- schedule_type
    1,  -- schedule_frequency
    1,  -- is_active (활성화)
    TO_CHAR(SYSDATE - (1/24), 'HH24:MI'),  -- preferred_time (현재 시간 - 1시간, 알림이 바로 표시되도록)
    SYSDATE  -- created_at
FROM dual
WHERE NOT EXISTS (
    SELECT 1 FROM routines
    WHERE user_id = 1 
      AND is_active = 1
      AND (UPPER(name) LIKE '%건조기%' OR UPPER(name) LIKE '%DRYER%')
);

COMMIT;

-- 확인 쿼리
SELECT 
    id, 
    name, 
    preferred_time,
    is_active,
    CASE 
        WHEN preferred_time IS NOT NULL AND 
             TO_DATE(TO_CHAR(SYSDATE, 'YYYY-MM-DD') || ' ' || preferred_time, 'YYYY-MM-DD HH24:MI') < SYSDATE 
        THEN '알림 표시됨'
        ELSE '알림 안 표시됨'
    END as notification_status
FROM routines
WHERE user_id = 1
  AND is_active = 1
  AND (UPPER(name) LIKE '%건조기%' OR UPPER(name) LIKE '%DRYER%')
ORDER BY id DESC;

