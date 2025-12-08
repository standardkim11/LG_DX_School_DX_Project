-- routines 테이블에 schedule_frequency 컬럼 추가
-- 월 2회, 3회 등 빈도 정보를 저장

ALTER TABLE routines 
ADD schedule_frequency NUMBER DEFAULT 1;

-- 기존 데이터는 모두 1회로 설정 (기본값)
UPDATE routines 
SET schedule_frequency = 1 
WHERE schedule_frequency IS NULL;

-- 컬럼을 NOT NULL로 변경 (기본값이 있으므로 안전)
ALTER TABLE routines 
MODIFY schedule_frequency NUMBER NOT NULL;

-- 주석 추가
COMMENT ON COLUMN routines.schedule_frequency IS '스케줄 빈도 (1=1회, 2=2회, 3=3회 등). MONTHLY일 때 월 N회, WEEKLY일 때 주 N회를 의미';

