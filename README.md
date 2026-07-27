# AIPA 클라이언트 (Flutter)

AIPA Engine(FastAPI 서버)의 모바일 클라이언트.
가상 페르소나 패널 설문 시뮬레이션 · 페르소나/커뮤니티 AI 채팅 앱.

- 서버 저장소: `AIPA_Engine` — API 명세는 서버 쪽 인수인계 문서 참고
- 상태관리: Provider · HTTP: `http` 패키지 · 인증: 공유 Bearer 토큰 + SharedPreferences 세션(uid)

## 실행 방법

```bash
# 1. 환경변수 파일 생성 (없으면 서버 주소가 10.0.2.2:8080 으로 폴백되고 카카오 로그인 불가)
cp .env.example .env   # 값 채우기: API_BASE_URL, API_BEARER_TOKEN, KAKAO_NATIVE_APP_KEY

# 2. 의존성 설치 & 실행
flutter pub get
flutter run
```

- `.env` 는 `pubspec.yaml` 의 assets 로 번들링됩니다 — 값 변경 시 재빌드 필요.
- `API_BEARER_TOKEN` 은 **서버 `.env` 의 값과 동일**해야 쓰기 API(회원 수정, 히스토리/대화 저장)가 동작합니다.

## 코드 구조

| 경로 | 역할 |
|---|---|
| `lib/config/api_config.dart` | 서버 주소·토큰 단일 진입점 (`.env` 로드) |
| `lib/services/api_service.dart` | 페르소나·시뮬레이션·채팅·업로드·대화방 API |
| `lib/services/user_service.dart` | 회원가입/로그인/프로필/히스토리 API + 세션 저장 |
| `lib/providers/` | UserProvider, PersonaProvider, SurveyProvider, SelectionProvider |
| `lib/screens/` | 화면 16개 (라우트 정의: `lib/main.dart`) |
| `lib/models/` | UserModel, PersonaData, QuestionData 등 |

## 주의사항

- 소셜 로그인: Google/Kakao 모두 Firebase 없이 SDK 로 계정정보만 획득해 서버 PostgreSQL 에 저장.
  iOS 는 URL scheme 미구성 상태라 소셜 로그인이 동작하지 않음 (Android 전용).
- 서버 다운 시에도 mock 데이터로 화면이 동작하므로(페르소나 4명, 채팅 목응답 등)
  연동 문제를 놓치기 쉬움 — 서버 상태는 `{API_BASE_URL}/api/v1/monitoring/health` 로 확인.
- 구독(`/subscription`) 화면은 결제 API 미연동 (UI만 존재).
