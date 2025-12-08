-- ============================================================
-- 날씨 데이터 시연용 관리 스크립트
-- ============================================================
-- 사용법:
--   1. 모든 날씨 데이터 삭제: DELETE 부분만 실행
--   2. 오늘 날짜의 날씨 데이터 추가: INSERT 부분만 실행
--   3. 날씨 값 변경: UPDATE 부분 참고
-- ============================================================

-- ============================================================
-- 1. 모든 날씨 데이터 삭제
-- ============================================================
DELETE FROM weather_info;

-- 시퀀스 리셋 (선택사항 - ID를 1부터 다시 시작하려면)
-- ALTER SEQUENCE weather_info_id_seq RESTART WITH 1;


-- ============================================================
-- 2. 오늘 날짜의 날씨 데이터 추가 (시나리오별)
-- ============================================================
-- 날짜는 SYSDATE (오늘)로 자동 설정되므로 날짜만 변경하면 됩니다.

-- 시나리오 1: 맑음 (기본값)
INSERT INTO weather_info (id, temperature, humidity, weather, date, pm25, pm10)
VALUES (
    weather_info_id_seq.NEXTVAL,
    22.0,           -- 기온 (섭씨)
    55.0,           -- 습도 (%)
    '맑음',         -- 날씨: 맑음, 흐림, 비, 눈
    SYSDATE,        -- 오늘 날짜 (변경하려면 TO_DATE('2025-01-15', 'YYYY-MM-DD'))
    25.0,           -- PM2.5 (35 이상이면 미세먼지 경고)
    45.0            -- PM10 (75 이상이면 미세먼지 경고)
);

-- 시나리오 2: 비
-- INSERT INTO weather_info (id, temperature, humidity, weather, date, pm25, pm10)
-- VALUES (
--     weather_info_id_seq.NEXTVAL,
--     18.0,
--     75.0,
--     '비',
--     SYSDATE,
--     20.0,
--     35.0
-- );

-- 시나리오 3: 눈
-- INSERT INTO weather_info (id, temperature, humidity, weather, date, pm25, pm10)
-- VALUES (
--     weather_info_id_seq.NEXTVAL,
--     -5.0,
--     60.0,
--     '눈',
--     SYSDATE,
--     15.0,
--     30.0
-- );

-- 시나리오 4: 흐림
-- INSERT INTO weather_info (id, temperature, humidity, weather, date, pm25, pm10)
-- VALUES (
--     weather_info_id_seq.NEXTVAL,
--     20.0,
--     65.0,
--     '흐림',
--     SYSDATE,
--     30.0,
--     50.0
-- );

-- 시나리오 5: 맑음 + 미세먼지 높음 (PM2.5 >= 35 또는 PM10 >= 75)
-- INSERT INTO weather_info (id, temperature, humidity, weather, date, pm25, pm10)
-- VALUES (
--     weather_info_id_seq.NEXTVAL,
--     25.0,
--     50.0,
--     '맑음',
--     SYSDATE,
--     45.0,  -- PM2.5 높음 (35 이상)
--     80.0   -- PM10 높음 (75 이상)
-- );

-- 시나리오 6: 비 + 미세먼지 높음
-- INSERT INTO weather_info (id, temperature, humidity, weather, date, pm25, pm10)
-- VALUES (
--     weather_info_id_seq.NEXTVAL,
--     18.0,
--     75.0,
--     '비',
--     SYSDATE,
--     40.0,  -- PM2.5 높음
--     85.0   -- PM10 높음
-- );


-- ============================================================
-- 3. 오늘 날짜의 날씨 데이터만 업데이트 (이미 데이터가 있는 경우)
-- ============================================================
-- 날씨만 변경
-- UPDATE weather_info
-- SET weather = '비'
-- WHERE date = TRUNC(SYSDATE);

-- 미세먼지 수치만 변경 (미세먼지 경고 메시지 테스트용)
-- UPDATE weather_info
-- SET pm25 = 40.0, pm10 = 80.0
-- WHERE date = TRUNC(SYSDATE);

-- 모든 값 변경
-- UPDATE weather_info
-- SET 
--     temperature = 20.0,
--     humidity = 60.0,
--     weather = '흐림',
--     pm25 = 30.0,
--     pm10 = 55.0
-- WHERE date = TRUNC(SYSDATE);


-- ============================================================
-- 4. 오늘 날짜의 날씨 데이터 확인
-- ============================================================
-- SELECT * FROM weather_info WHERE date = TRUNC(SYSDATE);


-- ============================================================
-- 5. 날씨 코드 참고
-- ============================================================
-- 날씨 값 (weather 컬럼):
--   - '맑음' 또는 'clear'  → weather_code: 0
--   - '흐림' 또는 'cloudy' → weather_code: 1
--   - '비' 또는 'rain'    → weather_code: 2
--   - '눈' 또는 'snow'    → weather_code: 3
--
-- 미세먼지 기준:
--   - PM2.5 >= 35 → 미세먼지 경고 메시지 표시
--   - PM10 >= 75  → 미세먼지 경고 메시지 표시
--
-- 추천 메시지:
--   - 맑음: "맑은 날씨예요. 세탁기 돌리는건 어떠세요?"
--   - 비: "비가 예정된 오늘, 세탁기 돌리고 건조기 돌리는 것을 추천드려요."
--   - 눈: "눈이 예정된 오늘, 외출 시 주의하세요."
--   - 흐림: "흐린 날씨예요. 실내 활동을 추천드립니다."
--   - 미세먼지 높음: "미세먼지 수치가 높아요. 외출 시 주의하세요." (추가)

