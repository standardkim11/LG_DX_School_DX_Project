# seed_demo_data 실행 가이드

## 방법 1: 브라우저에서 호출

백엔드 서버가 실행 중인 상태에서 브라우저 주소창에 입력:

```
http://localhost:8088/api/recommend/seed-demo?user_id=1
```

특정 날짜로 설정:
```
http://localhost:8088/api/recommend/seed-demo?user_id=1&date=2025-12-12
```

## 방법 2: 터미널에서 curl 사용

```bash
curl http://localhost:8088/api/recommend/seed-demo?user_id=1
```

특정 날짜로 설정:
```bash
curl "http://localhost:8088/api/recommend/seed-demo?user_id=1&date=2025-12-12"
```

## 방법 3: Python 코드로 호출

```python
import requests

response = requests.get('http://localhost:8088/api/recommend/seed-demo?user_id=1')
print(response.json())
```

## 방법 4: Postman 사용

- Method: GET
- URL: `http://localhost:8088/api/recommend/seed-demo?user_id=1`
- 또는 Params:
  - `user_id`: 1
  - `date`: 2025-12-12 (선택사항)

## 주의사항

- **한 번만 실행하면 됩니다**: DB에 데이터가 저장되므로 처음 한 번만 실행하면 됩니다. 매번 호출할 필요가 없습니다!
- **기존 데이터 삭제**: seed_demo_data는 실행할 때마다 기존 테스트 데이터(ID 9001-9003)를 삭제하고 새로 생성합니다.
  - 데이터를 리셋하고 싶을 때만 다시 실행하세요.
- **백엔드 서버 실행 필요**: API 호출 전에 백엔드 서버가 실행 중이어야 합니다.
- **날짜 형식**: date 파라미터는 `YYYY-MM-DD` 형식을 사용합니다.

## 언제 다시 실행해야 하나요?

- 처음 테스트 데이터를 넣을 때: **한 번만 실행**
- 데이터를 초기화하고 싶을 때: 다시 실행 (기존 데이터 삭제 후 새로 생성)
- 다른 날짜로 데이터를 생성하고 싶을 때: date 파라미터로 지정 후 실행

## 생성되는 데이터

- 루틴 3개 (ID: 9001, 9002, 9003)
- 각 루틴의 실행 기록 (ID: 9101, 9102, 9103)
- 날씨 정보

## 확인 방법

API 호출 후 프론트엔드의 routine 화면에서 데이터가 표시되는지 확인하세요.

