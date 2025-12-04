-- ============================================
-- SQL Developer에서 테스트 데이터 직접 입력/삭제 예시
-- ============================================
-- 이 파일은 참고용입니다. SQL Developer에서 실행하거나 복사해서 사용하세요.
-- 
-- 사용 방법:
-- 1. SQL Developer에서 이 파일을 열거나 SQL 워크시트에서 실행
-- 2. 필요한 부분만 선택해서 실행
-- 3. COMMIT 후 프론트/백엔드에서 데이터 확인

-- ============================================
-- STATUS 값 정의 확인
-- ============================================
-- 모델 정의: status는 String(20) 타입
-- 하지만 실제 코드에서는 숫자(0, 1, 2, 3)를 사용합니다.
-- Oracle DB는 숫자를 문자열 컬럼에 저장할 때 자동 변환되지만,
-- 비교할 때는 문자열 "2"로 저장해야 할 수도 있습니다.
-- 
-- 현재 코드 기준:
-- 0 = PENDING (아직 시작하지 않음)
-- 1 = RUNNING (실행 중)
-- 2 = DONE (완료)  
-- 3 = FAILED (실패)

-- ============================================
-- 0. 테스트 데이터 삭제 (필요시 실행)
-- ============================================
-- 주의: 실행 전에 데이터 백업을 권장합니다!
-- 
-- ⚠️ 중요: 
-- - app.py를 실행해도 데이터는 자동으로 생성되지 않습니다!
-- - seed_data는 /api/recommend/seed-demo 엔드포인트를 호출해야만 생성됩니다.
-- - 따라서 삭제 후 다시 넣으려면 아래 방법 중 하나를 사용하세요:
--   1) SQL로 직접 INSERT (이 파일의 1-2번 섹션 참고)
--   2) 브라우저/Postman에서 GET http://localhost:8088/api/recommend/seed-demo 호출
--   3) curl 명령: curl http://localhost:8088/api/recommend/seed-demo

-- 특정 ID의 실행 기록 삭제
DELETE FROM routine_executions WHERE id IN (9201, 9202, 9203, 9204, 9205);
COMMIT;

-- seed-demo로 생성된 기본 테스트 데이터 삭제 (ID 9001-9003의 루틴 실행 기록)
DELETE FROM routine_executions WHERE id IN (9101, 9102, 9103);
COMMIT;

-- 특정 날짜 범위의 실행 기록 삭제 (예: 12월 데이터)
DELETE FROM routine_executions 
WHERE user_id = 1 
  AND start_time >= TO_DATE('2025-12-01', 'YYYY-MM-DD')
  AND start_time < TO_DATE('2026-01-01', 'YYYY-MM-DD');
COMMIT;

-- 특정 루틴의 모든 실행 기록 삭제
DELETE FROM routine_executions WHERE routine_id = 9001;
COMMIT;

-- 특정 사용자의 모든 실행 기록 삭제 (주의!)
DELETE FROM routine_executions WHERE user_id = 1;
COMMIT;

-- 모든 실행 기록 삭제 (매우 주의!)
-- DELETE FROM routine_executions;
-- COMMIT;

-- ============================================
-- 1. 완료된 루틴 실행 기록 추가 (오늘 날짜)
-- ============================================
-- 예: 오늘(2025-12-04)에 루틴 ID 9001을 완료한 기록
INSERT INTO routine_executions (
    id, user_id, routine_id, status, 
    start_time, end_time, run_time, 
    recommended_flag, priority_score, created_at
) VALUES (
    9201,  -- 새 ID (기존과 중복되지 않게)
    1,     -- user_id
    9001,  -- routine_id (아침 세탁기 돌리기)
    2,     -- status = 2 (DONE, 완료) - 숫자로 저장
    TO_DATE('2025-12-04 07:30:00', 'YYYY-MM-DD HH24:MI:SS'),  -- 시작 시간
    TO_DATE('2025-12-04 08:10:00', 'YYYY-MM-DD HH24:MI:SS'),  -- 종료 시간
    40,    -- run_time (분)
    1,     -- recommended_flag (1=true)
    NULL,  -- priority_score
    SYSDATE  -- created_at
);

-- ============================================
-- 2. 여러 루틴 완료 기록 추가 (월간 통계용)
-- ============================================
-- 12월에 완료된 여러 루틴 기록을 추가하려면:

-- 루틴 9001 완료 (12월 1일)
INSERT INTO routine_executions (id, user_id, routine_id, status, start_time, end_time, run_time, recommended_flag, created_at)
VALUES (9202, 1, 9001, 2, TO_DATE('2025-12-01 07:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_DATE('2025-12-01 07:40:00', 'YYYY-MM-DD HH24:MI:SS'), 40, 1, SYSDATE);

-- 루틴 9002 완료 (12월 1일)
INSERT INTO routine_executions (id, user_id, routine_id, status, start_time, end_time, run_time, recommended_flag, created_at)
VALUES (9203, 1, 9002, 2, TO_DATE('2025-12-01 15:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_DATE('2025-12-01 15:30:00', 'YYYY-MM-DD HH24:MI:SS'), 30, 1, SYSDATE);

-- 루틴 9003 완료 (12월 1일)
INSERT INTO routine_executions (id, user_id, routine_id, status, start_time, end_time, run_time, recommended_flag, created_at)
VALUES (9204, 1, 9003, 2, TO_DATE('2025-12-01 21:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_DATE('2025-12-01 21:50:00', 'YYYY-MM-DD HH24:MI:SS'), 50, 1, SYSDATE);

-- 실패한 루틴 기록 (12월 2일)
INSERT INTO routine_executions (id, user_id, routine_id, status, start_time, end_time, run_time, recommended_flag, created_at)
VALUES (9205, 1, 9001, 3, TO_DATE('2025-12-02 07:00:00', 'YYYY-MM-DD HH24:MI:SS'), NULL, NULL, 0, SYSDATE);

-- ============================================
-- 3. 기존 데이터의 STATUS 업데이트
-- ============================================
-- 현재 STATUS=0인 데이터를 완료 상태로 변경하려면:
UPDATE routine_executions
SET status = 2,  -- DONE (완료)
    end_time = start_time + (run_time / 1440),  -- start_time + run_time(분)을 일로 변환
    recommended_flag = 1
WHERE id IN (9101, 9102, 9103)  -- 특정 ID들만
  AND status = 0;  -- 현재 PENDING인 것만

-- 또는 오늘 날짜의 모든 PENDING을 완료로:
UPDATE routine_executions
SET status = 2,
    end_time = start_time + (run_time / 1440),
    recommended_flag = 1
WHERE user_id = 1
  AND status = 0
  AND TRUNC(start_time) = TRUNC(SYSDATE);  -- 오늘 날짜

-- ============================================
-- 4. 확인 쿼리
-- ============================================
-- STATUS별 개수 확인:
SELECT status, COUNT(*) as count
FROM routine_executions
WHERE user_id = 1
  AND start_time >= TO_DATE('2025-12-01', 'YYYY-MM-DD')
GROUP BY status
ORDER BY status;

-- 오늘 완료된 루틴 확인:
SELECT re.*, r.name as routine_name
FROM routine_executions re
JOIN routines r ON re.routine_id = r.id
WHERE re.user_id = 1
  AND re.status = 2
  AND TRUNC(re.start_time) = TRUNC(SYSDATE);

-- ============================================
-- 5. 주의사항
-- ============================================
-- 1. STATUS 값은 숫자(0, 1, 2, 3)로 저장하세요
-- 2. start_time은 DateTime 형식이어야 합니다
-- 3. end_time은 완료 시에만 설정 (NULL 가능)
-- 4. run_time은 분 단위입니다
-- 5. recommended_flag는 0(false) 또는 1(true)
-- 6. user_id와 routine_id는 실제 존재하는 값이어야 합니다

-- ============================================
-- 6. 커밋 (변경사항 저장)
-- ============================================
COMMIT;

-- ============================================
-- 8. seed-demo 엔드포인트 사용법 (참고)
-- ============================================
-- Python 코드로 seed_data를 자동 실행하는 방법:
-- 
-- 방법 1: 브라우저에서 직접 호출
--   http://localhost:8088/api/recommend/seed-demo?user_id=1
--
-- 방법 2: curl 명령어 (터미널/PowerShell)
--   curl http://localhost:8088/api/recommend/seed-demo?user_id=1
--
-- 방법 3: Python 코드에서
--   import requests
--   response = requests.get('http://localhost:8088/api/recommend/seed-demo?user_id=1')
--
-- ⚠️ 주의:
-- - seed-demo는 기존 데이터(9001-9003)를 삭제하고 새로 생성합니다
-- - STATUS=0 (PENDING)으로 생성되므로, 완료 상태로 만들려면 3번 섹션의 UPDATE 사용

-- ============================================
-- 7. 데이터 확인 쿼리
-- ============================================
-- 입력한 데이터가 제대로 저장되었는지 확인:

-- 모든 실행 기록 확인
SELECT * FROM routine_executions WHERE user_id = 1 ORDER BY start_time DESC;

-- 오늘 완료된 루틴 확인
SELECT re.*, r.name as routine_name
FROM routine_executions re
JOIN routines r ON re.routine_id = r.id
WHERE re.user_id = 1
  AND re.status = 2
  AND TRUNC(re.start_time) = TRUNC(SYSDATE);

-- 12월 통계 확인 (대시보드 데이터)
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
-- 8. 습관 목표 설정 (시연용)
-- ============================================
-- 루틴에 습관 목표를 설정하면 대시보드에서 습관 카드가 표시됩니다.
-- 예: routine_id=9001 (아침 세탁기 돌리기)를 21일 목표의 메인 습관으로 설정

-- 습관 목표 설정
UPDATE routines 
SET HABIT_GOAL_DAYS = 21,                    -- 21일 목표
    HABIT_START_DATE = TO_DATE('2025-12-01', 'YYYY-MM-DD')  -- 12월 1일부터 시작
WHERE id = 9001;  -- 아침 세탁기 돌리기 루틴

COMMIT;

-- 설정 확인
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
ORDER BY id;

-- 습관 목표 제거 (필요시)
-- UPDATE routines 
-- SET HABIT_GOAL_DAYS = NULL,
--     HABIT_START_DATE = NULL
-- WHERE id = 9001;
-- COMMIT;

