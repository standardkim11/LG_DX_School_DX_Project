-- ============================================
-- 테스트 데이터 롤백 스크립트
-- ============================================
-- SQL_TEST_DATA_EXAMPLES.sql에서 추가한 테스트 데이터를 삭제합니다.
-- 실행 전에 반드시 확인 후 실행하세요!

-- ============================================
-- 1. 대시보드 테스트에서 추가한 실행 기록 삭제
-- ============================================
-- 9번 섹션에서 추가한 모든 실행 기록 삭제
DELETE FROM routine_executions 
WHERE id IN (9201, 9202, 9203, 9204, 9205, 9206);
COMMIT;

-- 확인: 삭제된 데이터 확인
SELECT COUNT(*) as remaining_count
FROM routine_executions 
WHERE id IN (9201, 9202, 9203, 9204, 9205, 9206);
-- 결과가 0이면 정상적으로 삭제된 것입니다.

-- ============================================
-- 2. 습관 목표 설정 제거 (선택사항)
-- ============================================
-- 만약 습관 목표 설정도 원래대로 돌리고 싶다면:
-- UPDATE routines 
-- SET HABIT_GOAL_DAYS = NULL,
--     HABIT_START_DATE = NULL
-- WHERE id = 9001;
-- COMMIT;

-- ============================================
-- 3. 전체 테스트 데이터 삭제 (주의!)
-- ============================================
-- 모든 테스트용 실행 기록을 삭제하려면 (9200번대 ID 모두):
-- DELETE FROM routine_executions 
-- WHERE id >= 9200 AND id < 9300;
-- COMMIT;

-- ============================================
-- 4. 확인 쿼리
-- ============================================
-- 삭제 후 현재 상태 확인:
SELECT 
    COUNT(*) as total_executions,
    SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) as completed,
    SUM(CASE WHEN status = 3 THEN 1 ELSE 0 END) as failed,
    SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) as pending
FROM routine_executions
WHERE user_id = 1;

-- 오늘 날짜의 실행 기록 확인:
SELECT re.*, r.name as routine_name
FROM routine_executions re
JOIN routines r ON re.routine_id = r.id
WHERE re.user_id = 1
  AND TRUNC(re.start_time) = TRUNC(SYSDATE)
ORDER BY re.start_time DESC;

