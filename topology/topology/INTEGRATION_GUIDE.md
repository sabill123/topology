# iOS 앱과 백엔드 연동 가이드

## 1. 백엔드 시작하기

### 필수 사항
- Python 3.9 이상
- Redis 설치 및 실행
- Google Sheets API 설정

### 백엔드 실행 순서

1. **터미널 1 - Redis 시작**:
```bash
# macOS (Homebrew)
brew services start redis

# 또는 직접 실행
redis-server
```

2. **터미널 2 - 백엔드 서버 시작**:
```bash
cd /Users/jaeseokhan/Desktop/topology/topology/topology/be

# 가상환경 생성 (처음 한 번만)
python -m venv venv

# 가상환경 활성화
source venv/bin/activate  # Windows: venv\Scripts\activate

# 의존성 설치 (처음 한 번만)
pip install -r requirements.txt

# Google Sheets 설정 (처음 한 번만)
python setup_sheets.py

# 서버 시작
uvicorn main:app --reload
```

3. **API 문서 확인**:
- http://localhost:8000/docs - Swagger UI
- http://localhost:8000/redoc - ReDoc

## 2. iOS 앱 실행하기

1. **Xcode에서 프로젝트 열기**:
```bash
cd /Users/jaeseokhan/Desktop/topology/topology/topology
open .
```

2. **시뮬레이터에서 실행**:
- Xcode에서 ⌘+R 또는 Run 버튼 클릭
- iOS 시뮬레이터 선택 후 실행

## 3. 테스트 계정 만들기

### 백엔드 API로 직접 가입:
```bash
curl -X POST "http://localhost:8000/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "password123",
    "display_name": "테스트 유저",
    "age": 25,
    "gender": "male",
    "country": "한국"
  }'
```

### 또는 앱에서 가입:
1. 앱 실행
2. "Don't have an account? Register" 클릭
3. 정보 입력 후 가입

## 4. 기능 테스트

### 로그인
- 사용자명/이메일과 비밀번호로 로그인
- 자동으로 WebSocket 연결됨

### 친구 관리
- 친구 목록 조회
- 친구 요청 보내기/받기
- 친구 요청 수락/거절

### 채팅
- 실시간 메시지 전송
- 타이핑 표시기
- 읽음 확인

### 비디오 통화
- WebRTC 시그널링
- 통화 발신/수신

## 5. 개발 디버깅

### 백엔드 로그 확인
- 터미널에서 실시간 로그 확인 가능
- Redis 모니터링: `redis-cli monitor`

### iOS 앱 로그 확인
- Xcode 콘솔에서 확인
- Network 탭에서 API 요청 확인

### 일반적인 문제 해결

1. **"Connection refused" 오류**:
   - 백엔드 서버가 실행 중인지 확인
   - Redis가 실행 중인지 확인

2. **"Unauthorized" 오류**:
   - 토큰이 올바른지 확인
   - 토큰이 만료되지 않았는지 확인

3. **WebSocket 연결 실패**:
   - 백엔드 서버가 실행 중인지 확인
   - 토큰이 올바른지 확인

## 6. 프로덕션 준비

### 백엔드
1. `.env` 파일에서 프로덕션 설정으로 변경
2. `SECRET_KEY` 변경
3. CORS 설정 업데이트
4. HTTPS 설정

### iOS 앱
1. `APIClient.swift`에서 `baseURL`을 프로덕션 URL로 변경
2. Info.plist에서 NSAppTransportSecurity 설정 제거 (HTTPS 사용 시)
3. 앱 서명 및 프로비저닝 프로파일 설정

## 7. 추가 리소스

- [FastAPI 문서](https://fastapi.tiangolo.com/)
- [SwiftUI 문서](https://developer.apple.com/documentation/swiftui)
- [WebRTC 문서](https://webrtc.org/)
- [Google Sheets API](https://developers.google.com/sheets/api)