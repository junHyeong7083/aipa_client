import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import '../models/user_model.dart';
import '../models/user_data.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();

  UserModel? _currentUser;
  UserData? _user;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  List<SurveyHistory> _history = [];

  UserModel? get currentUser => _currentUser;
  UserData? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SurveyHistory> get history => _history;

  /// 앱 시작 시 자동 로그인 체크
  Future<bool> checkAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 저장된 세션(uid + provider) 확인 — 모든 provider 공통
      final savedUid = await _userService.getSavedUid();
      final savedProvider = await _userService.getSavedProvider();

      if (savedUid != null) {
        debugPrint('저장된 세션 발견: $savedUid ($savedProvider)');

        // 카카오는 토큰 유효성도 확인 (만료 시 세션 정리)
        if (savedProvider == AuthProvider.kakao) {
          try {
            await kakao.UserApi.instance.accessTokenInfo();
          } catch (e) {
            debugPrint('카카오 토큰 만료: $e');
            await _userService.clearLocalSession();
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }

        // 서버에서 사용자 정보 로드
        final userModel = await _userService.getUser(savedUid);
        if (userModel != null) {
          _currentUser = userModel;
          _setUserDataFromModel(userModel);
          _isLoggedIn = true;
          _isLoading = false;
          await loadHistory();
          notifyListeners();
          return true;
        }
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('자동 로그인 체크 실패: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Google 로그인
  Future<bool> loginWithGoogle(String uid, String email, String name,
      {String? profileImage}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 서버에 사용자 저장/업데이트
      final userModel = await _userService.createOrUpdateUser(
        uid: uid,
        email: email,
        displayName: name,
        profileImage: profileImage,
        provider: AuthProvider.google,
      );

      // 세션 저장 (자동 로그인용)
      await _userService.saveSession(uid, AuthProvider.google);

      _currentUser = userModel;
      _setUserDataFromModel(userModel);
      _isLoggedIn = true;
      _isLoading = false;

      await loadHistory();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Kakao 로그인
  Future<bool> loginWithKakao(String uid, String email, String name,
      {String? profileImage}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final kakaoUid = 'kakao_$uid';

      // 서버에 사용자 저장/업데이트
      final userModel = await _userService.createOrUpdateUser(
        uid: kakaoUid,
        email: email,
        displayName: name,
        profileImage: profileImage,
        provider: AuthProvider.kakao,
      );

      // 세션 저장 (자동 로그인용)
      await _userService.saveSession(kakaoUid, AuthProvider.kakao);

      _currentUser = userModel;
      _setUserDataFromModel(userModel);
      _isLoggedIn = true;
      _isLoading = false;

      await loadHistory();
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('loginWithKakao 에러: $e');
      debugPrint('스택트레이스: $stackTrace');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 이메일 기반 안정적 id 생성 (이메일이 unique 하므로 결정적)
  String _emailUid(String email) =>
      'email_${email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

  /// 이메일 회원가입 (서버 POST /users)
  Future<bool> signUp(String email, String password, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userModel = await _userService.createOrUpdateUser(
        uid: _emailUid(email),
        email: email,
        displayName: name,
        provider: AuthProvider.email,
        password: password,
      );

      await _userService.saveSession(userModel.uid, AuthProvider.email);

      _currentUser = userModel;
      _setUserDataFromModel(userModel);
      _isLoggedIn = true;
      _isLoading = false;

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 이메일 로그인 (서버 POST /users/login)
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userModel = await _userService.loginLocal(email, password);

      await _userService.saveSession(userModel.uid, AuthProvider.email);

      _currentUser = userModel;
      _setUserDataFromModel(userModel);
      _isLoggedIn = true;
      _isLoading = false;

      await loadHistory();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    try {
      // Google Sign Out
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        debugPrint('Google 로그아웃 에러 (무시): $e');
      }

      // 카카오 로그아웃
      try {
        await kakao.UserApi.instance.logout();
      } catch (e) {
        debugPrint('카카오 로그아웃 에러 (무시): $e');
      }

      // 로컬 세션 삭제
      await _userService.clearLocalSession();

      // 상태 초기화
      _currentUser = null;
      _user = null;
      _isLoggedIn = false;
      _history = [];

      notifyListeners();
    } catch (e) {
      debugPrint('로그아웃 에러: $e');
    }
  }

  /// 관심사 업데이트
  Future<void> updateInterests(List<String> interests) async {
    if (_currentUser == null) return;

    try {
      await _userService.updateInterests(_currentUser!.uid, interests);
      _currentUser = _currentUser!.copyWith(interests: interests);
      notifyListeners();
    } catch (e) {
      debugPrint('관심사 업데이트 실패: $e');
    }
  }

  /// 이름 업데이트
  Future<bool> updateDisplayName(String newName) async {
    if (_currentUser == null) return false;

    try {
      await _userService.updateDisplayName(_currentUser!.uid, newName);
      _currentUser = _currentUser!.copyWith(displayName: newName);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('이름 업데이트 실패: $e');
      return false;
    }
  }

  /// 프로필 이미지 업데이트
  Future<bool> updateProfileImage(String? imageUrl) async {
    if (_currentUser == null) return false;

    try {
      await _userService.updateProfileImage(_currentUser!.uid, imageUrl);
      _currentUser = _currentUser!.copyWith(profileImage: imageUrl);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('프로필 이미지 업데이트 실패: $e');
      return false;
    }
  }

  /// UserModel을 UserData로 변환
  void _setUserDataFromModel(UserModel model) {
    _user = UserData(
      id: model.uid,
      email: model.email,
      name: model.displayName,
      plan: SubscriptionPlan.free,
      surveysRemaining: 3,
    );
  }

  /// 구독 업그레이드
  Future<bool> upgradePlan(SubscriptionPlan newPlan) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      // TODO: 실제 결제 API 연동
      await Future.delayed(const Duration(seconds: 1));

      _user = _user!.copyWith(
        plan: newPlan,
        planExpiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 설문 히스토리 로드
  Future<void> loadHistory() async {
    if (_currentUser == null) return;

    try {
      _history = await _userService.loadSurveyHistory(_currentUser!.uid);
    } catch (e) {
      debugPrint('히스토리 로드 실패: $e');
      _history = [];
    }
    notifyListeners();
  }

  /// 설문 횟수 차감 (무료 플랜용)
  void decrementSurveyCount() {
    if (_user != null && _user!.plan == SubscriptionPlan.free) {
      _user = _user!.copyWith(
        surveysRemaining: _user!.surveysRemaining - 1,
      );
      notifyListeners();
    }
  }

  /// 히스토리에 추가 (Firestore에도 저장)
  Future<void> addToHistory(SurveyHistory survey) async {
    _history.insert(0, survey);
    notifyListeners();

    if (_currentUser != null) {
      try {
        await _userService.saveSurveyHistory(_currentUser!.uid, survey);
      } catch (e) {
        debugPrint('히스토리 Firestore 저장 실패: $e');
      }
    }
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
