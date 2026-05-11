# AIPA 인증 시스템 문서

## 개요

AIPA 앱의 사용자 인증 및 세션 관리 시스템에 대한 문서입니다.

## 지원하는 로그인 방식

| 방식 | 제공자 | 세션 유지 |
|------|--------|----------|
| Google | Firebase Auth | 자동 (Firebase) |
| Kakao | Kakao SDK | SharedPreferences |
| 이메일 | Firebase Auth | 자동 (Firebase) |
| 게스트 | - | 없음 |

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                      앱 실행                            │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│              SplashScreen (main.dart)                   │
│           - Firebase Auth 세션 확인                      │
│           - Kakao 토큰 확인                             │
└─────────────────────────────────────────────────────────┘
                          ↓
          ┌───────────────┴───────────────┐
          ↓                               ↓
   [로그인 됨]                      [로그인 안됨]
          ↓                               ↓
   [메인 화면]                      [로그인 화면]
```

## 파일 구조

```
lib/
├── main.dart                    # SplashScreen (자동 로그인 체크)
├── models/
│   ├── user_model.dart          # Firestore 사용자 모델
│   └── user_data.dart           # 앱 내부 사용자 데이터
├── services/
│   └── user_service.dart        # Firestore CRUD + 세션 관리
├── providers/
│   └── user_provider.dart       # 상태 관리 + 인증 로직
└── screens/
    ├── login_screen.dart        # 로그인/회원가입 UI
    └── main_menu_screen.dart    # 로그아웃 기능
```

## Firestore 데이터 구조

### users 컬렉션

```
firestore/
└── users (컬렉션)
    └── {uid} (문서)
        ├── uid: string              # 고유 ID
        ├── email: string            # 이메일
        ├── displayName: string      # 표시 이름
        ├── profileImage: string?    # 프로필 이미지 URL
        ├── provider: string         # "google" | "kakao" | "email"
        ├── createdAt: timestamp     # 가입 일시
        ├── lastLoginAt: timestamp   # 마지막 로그인 일시
        └── interests: array?        # 관심 분야
```

### UID 규칙

| 로그인 방식 | UID 형식 | 예시 |
|------------|----------|------|
| Google | Firebase UID | `abc123xyz...` |
| Kakao | `kakao_{카카오ID}` | `kakao_1234567890` |
| 이메일 | Firebase UID | `def456abc...` |

## 주요 클래스

### UserModel (`lib/models/user_model.dart`)

Firestore에 저장되는 사용자 모델

```dart
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? profileImage;
  final AuthProvider provider;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final List<String>? interests;
}
```

### UserService (`lib/services/user_service.dart`)

Firestore CRUD 및 로컬 세션 관리

```dart
class UserService {
  // Firestore 작업
  Future<UserModel?> getUser(String uid);
  Future<UserModel> createOrUpdateUser({...});
  Future<void> updateInterests(String uid, List<String> interests);

  // 로컬 세션 관리 (카카오용)
  Future<void> saveKakaoSession(String uid);
  Future<String?> getSavedKakaoUid();
  Future<void> clearLocalSession();
}
```

### UserProvider (`lib/providers/user_provider.dart`)

상태 관리 및 인증 로직

```dart
class UserProvider extends ChangeNotifier {
  // 자동 로그인
  Future<bool> checkAutoLogin();

  // 로그인
  Future<bool> loginWithGoogle(String uid, String email, String name, {String? profileImage});
  Future<bool> loginWithKakao(String uid, String email, String name, {String? profileImage});
  Future<bool> login(String email, String password);

  // 회원가입
  Future<bool> signUp(String email, String password, String name);

  // 로그아웃
  Future<void> logout();
}
```

## 인증 흐름

### 1. 앱 시작 (자동 로그인)

```
SplashScreen.initState()
    ↓
UserProvider.checkAutoLogin()
    ↓
┌─ Firebase Auth 세션 확인
│   └─ 있으면 → Firestore에서 사용자 정보 로드 → 메인 화면
│
└─ Kakao 토큰 확인 (SharedPreferences)
    └─ 있으면 → 토큰 유효성 검사 → Firestore에서 사용자 정보 로드 → 메인 화면

없으면 → 로그인 화면
```

### 2. Google 로그인

```
_signInWithGoogle()
    ↓
GoogleSignIn().signIn()
    ↓
Firebase Auth signInWithCredential()
    ↓
UserProvider.loginWithGoogle()
    ↓
UserService.createOrUpdateUser()  → Firestore 저장
    ↓
메인 화면으로 이동
```

### 3. Kakao 로그인

```
_signInWithKakao()
    ↓
kakao.UserApi.instance.loginWithKakaoTalk() 또는 loginWithKakaoAccount()
    ↓
UserProvider.loginWithKakao()
    ↓
UserService.createOrUpdateUser()  → Firestore 저장
UserService.saveKakaoSession()    → SharedPreferences 저장
    ↓
메인 화면으로 이동
```

### 4. 이메일 회원가입

```
_completeSignup()
    ↓
UserProvider.signUp()
    ↓
Firebase Auth createUserWithEmailAndPassword()
    ↓
UserService.createOrUpdateUser()  → Firestore 저장
    ↓
메인 화면으로 이동
```

### 5. 로그아웃

```
logout 버튼 클릭
    ↓
UserProvider.logout()
    ↓
Firebase Auth signOut()
GoogleSignIn().signOut()
kakao.UserApi.instance.logout()
UserService.clearLocalSession()   → SharedPreferences 삭제
    ↓
로그인 화면으로 이동
```

## Firebase 설정

### 필수 서비스

1. **Firebase Authentication**
   - Google 로그인 활성화
   - 이메일/비밀번호 로그인 활성화

2. **Cloud Firestore**
   - 위치: asia-northeast3 (서울)
   - 테스트 모드로 시작 (개발용)

### google-services.json

- 위치: `android/app/google-services.json`
- SHA-1 인증서 지문 등록 필요 (Google 로그인용)

## Kakao 설정

### 환경변수

```env
KAKAO_NATIVE_APP_KEY=b8e66cb30c12b03ff853c4fd9b58ec8b
```

### 카카오 개발자 콘솔

1. 앱 등록
2. Android 플랫폼 추가
3. 패키지명: `com.aipa.app`
4. 키 해시 등록

### AndroidManifest.xml

OAuth 콜백 액티비티 등록:

```xml
<activity
    android:name="com.kakao.sdk.flutter.AuthCodeCustomTabsActivity"
    android:exported="true">
    <intent-filter android:label="flutter_web_auth">
        <data android:scheme="kakao{NATIVE_APP_KEY}" android:host="oauth"/>
    </intent-filter>
</activity>
```

## 보안 고려사항

### Firestore 보안 규칙 (프로덕션용)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 카카오 로그인 보안

- 카카오 토큰은 Kakao SDK가 자체적으로 안전하게 관리
- SharedPreferences에는 UID만 저장 (토큰 X)
- 앱 시작 시 토큰 유효성 검사 수행

## 테스트 체크리스트

- [ ] Google 로그인 → 메인 화면 이동
- [ ] Google 로그인 후 Firestore에 사용자 저장 확인
- [ ] Kakao 로그인 → 메인 화면 이동
- [ ] Kakao 로그인 후 Firestore에 사용자 저장 확인
- [ ] 이메일 회원가입 → 메인 화면 이동
- [ ] 이메일 회원가입 후 Firestore에 사용자 저장 확인
- [ ] 앱 종료 후 재시작 → 자동 로그인 (메인 화면으로 바로 이동)
- [ ] 로그아웃 → 로그인 화면으로 이동
- [ ] 로그아웃 후 앱 재시작 → 로그인 화면 표시
