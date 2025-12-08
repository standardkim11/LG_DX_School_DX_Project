-- routine_executions 테이블 성능 최적화를 위한 인덱스 추가
-- COUNT 쿼리 성능 향상을 위해 복합 인덱스 생성
-- Oracle 식별자 길이 제한(30바이트)에 맞춰 짧은 이름 사용

-- 1. 목표 달성 체크를 위한 인덱스 (WEEKLY/MONTHLY 루틴)
-- user_id, routine_id, start_time, status 조합으로 빠른 필터링
CREATE INDEX idx_exec_goal 
ON routine_executions(user_id, routine_id, start_time, status);

-- 2. 오늘 완료 여부 체크를 위한 인덱스
-- user_id, routine_id, start_time 조합으로 오늘 날짜 범위 쿼리 최적화
CREATE INDEX idx_exec_today 
ON routine_executions(user_id, routine_id, start_time);

-- 3. 마지막 완료 날짜 조회를 위한 인덱스
-- user_id, routine_id, start_time DESC로 정렬된 조회 최적화
CREATE INDEX idx_exec_last 
ON routine_executions(user_id, routine_id, start_time DESC);

-- 4. status 필터링을 위한 인덱스 (완료된 것만 조회)
-- Oracle에서는 함수 기반 인덱스나 조건부 인덱스가 제한적이므로
-- 일반 인덱스로 생성 (status가 자주 필터링되는 경우)
CREATE INDEX idx_exec_status 
ON routine_executions(status);

-- 주석: 인덱스는 쿼리 패턴에 따라 자동으로 선택되므로
-- 여러 인덱스를 생성해도 성능에 부정적 영향을 주지 않습니다.
-- 오히려 쿼리 최적화기가 가장 적합한 인덱스를 선택합니다.

