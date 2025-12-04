-- ============================================
-- 대시보드 테스트용 데이터 추가 (SQL Developer용)
-- ============================================
-- 이 쿼리를 실행하면 대시보드에 표시될 데이터가 추가됩니다.
-- 실행 후 Flutter 앱에서 대시보드를 새로고침하면 데이터가 표시됩니다.

-- ============================================
-- 1. 기존 테스트 데이터 확인 (선택사항)
-- ============================================
-- 먼저 현재 데이터 상태를 확인해보세요:
SELECT 
    COUNT(*) as total_logs,
    SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) as completed,
    SUM(CASE WHEN status = 3 THEN 1 ELSE 0 END) as failed,
    SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) as pending
FROM routine_executions
WHERE user_id = 1
  AND start_time >= TO_DATE('2025-12-01', 'YYYY-MM-DD')
  AND start_time < TO_DATE('2026-01-01', 'YYYY-MM-DD');

-- ============================================
-- 2. 12월 완료된 루틴 실행 기록 추가
-- ============================================
-- 여러 날짜에 걸쳐 완료된 루틴 기록을 추가합니다.

-- 12월 1일: 루틴 9001 완료
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9301, 1, 9001, 2,  -- status = 2 (DONE)
    TO_DATE('2025-12-01 07:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_DATE('2025-12-01 08:10:00', 'YYYY-MM-DD HH24:MI:SS'),
    40, 1, NULL, SYSDATE
);

-- 12월 2일: 루틴 9001 완료
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9302, 1, 9001, 2,
    TO_DATE('2025-12-02 07:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_DATE('2025-12-02 07:40:00', 'YYYY-MM-DD HH24:MI:SS'),
    40, 1, NULL, SYSDATE
);

-- 12월 2일: 루틴 9002 완료
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9303, 1, 9002, 2,
    TO_DATE('2025-12-02 15:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_DATE('2025-12-02 15:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    30, 1, NULL, SYSDATE
);

-- 12월 3일: 루틴 9001 완료
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9304, 1, 9001, 2,
    TO_DATE('2025-12-03 07:15:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_DATE('2025-12-03 07:55:00', 'YYYY-MM-DD HH24:MI:SS'),
    40, 1, NULL, SYSDATE
);

-- 12월 3일: 루틴 9003 완료
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9305, 1, 9003, 2,
    TO_DATE('2025-12-03 21:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_DATE('2025-12-03 21:50:00', 'YYYY-MM-DD HH24:MI:SS'),
    50, 1, NULL, SYSDATE
);

-- 12월 4일: 루틴 9001 완료
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9306, 1, 9001, 2,
    TO_DATE('2025-12-04 07:20:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_DATE('2025-12-04 08:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    40, 1, NULL, SYSDATE
);

-- 12월 4일: 루틴 9002 완료
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9307, 1, 9002, 2,
    TO_DATE('2025-12-04 14:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_DATE('2025-12-04 15:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    30, 1, NULL, SYSDATE
);

-- 12월 5일: 루틴 9001 완료
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9308, 1, 9001, 2,
    TO_DATE('2025-12-05 07:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    TO_DATE('2025-12-05 07:40:00', 'YYYY-MM-DD HH24:MI:SS'),
    40, 1, NULL, SYSDATE
);

-- ============================================
-- 3. 실패한 루틴 실행 기록 추가
-- ============================================
-- 실패한 루틴 기록을 추가하여 실패율도 확인할 수 있도록 합니다.

-- 12월 1일: 루틴 9002 실패
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9401, 1, 9002, 3,  -- status = 3 (FAILED)
    TO_DATE('2025-12-01 15:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    NULL,  -- 실패한 경우 end_time은 NULL
    NULL,  -- run_time도 NULL
    0, NULL, SYSDATE
);

-- 12월 4일: 루틴 9003 실패
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9402, 1, 9003, 3,
    TO_DATE('2025-12-04 21:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    NULL,
    NULL,
    0, NULL, SYSDATE
);

-- ============================================
-- 4. 습관 목표 설정 (습관 카드 표시용)
-- ============================================
-- 루틴 9001에 습관 목표를 설정하면 대시보드에 습관 카드가 표시됩니다.

UPDATE routines 
SET HABIT_GOAL_DAYS = 21,                    -- 21일 목표
    HABIT_START_DATE = TO_DATE('2025-12-01', 'YYYY-MM-DD')  -- 12월 1일부터 시작
WHERE id = 9001;  -- 아침 세탁기 돌리기 루틴

-- ============================================
-- 5. 변경사항 저장
-- ============================================
COMMIT;

-- ============================================
-- 6. 데이터 확인 쿼리
-- ============================================
-- 추가한 데이터가 제대로 저장되었는지 확인:

-- 12월 전체 통계 확인
SELECT 
    COUNT(*) as total_logs,
    SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) as completed_count,
    SUM(CASE WHEN status = 3 THEN 1 ELSE 0 END) as failed_count,
    SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) as pending_count,
    ROUND(
        SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(CASE WHEN status IN (2, 3) THEN 1 ELSE 0 END), 0), 
        2
    ) as success_rate_percent
FROM routine_executions
WHERE user_id = 1
  AND start_time >= TO_DATE('2025-12-01', 'YYYY-MM-DD')
  AND start_time < TO_DATE('2026-01-01', 'YYYY-MM-DD');

-- 날짜별 완료/실패 현황
SELECT 
    TO_CHAR(TRUNC(start_time), 'YYYY-MM-DD') as date,
    SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) as completed,
    SUM(CASE WHEN status = 3 THEN 1 ELSE 0 END) as failed
FROM routine_executions
WHERE user_id = 1
  AND start_time >= TO_DATE('2025-12-01', 'YYYY-MM-DD')
  AND start_time < TO_DATE('2026-01-01', 'YYYY-MM-DD')
GROUP BY TRUNC(start_time)
ORDER BY TRUNC(start_time);

-- 습관 목표 설정 확인
SELECT 
    id,
    name,
    HABIT_GOAL_DAYS,
    HABIT_START_DATE,
    CASE 
        WHEN HABIT_GOAL_DAYS IS NOT NULL THEN '습관 목표 설정됨'
        ELSE '습관 목표 없음'
    END as habit_status
FROM routines
WHERE user_id = 1
  AND id = 9001;

-- ============================================
-- 7. 데이터 삭제 (필요시)
-- ============================================
-- 테스트 후 데이터를 삭제하려면 아래 쿼리를 실행하세요:

-- 방금 추가한 실행 기록 삭제
-- DELETE FROM routine_executions WHERE id IN (9301, 9302, 9303, 9304, 9305, 9306, 9307, 9308, 9401, 9402);
-- COMMIT;

-- 습관 목표 제거
-- UPDATE routines 
-- SET HABIT_GOAL_DAYS = NULL,
--     HABIT_START_DATE = NULL
-- WHERE id = 9001;
-- COMMIT;

