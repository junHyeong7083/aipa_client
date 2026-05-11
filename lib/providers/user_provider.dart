import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import '../models/user_model.dart';
import '../models/user_data.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

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
      // 1. Firebase Auth 세션 확인 (Google, Email)
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        debugPrint('Firebase 세션 발견: ${firebaseUser.uid}');

        // Firestore에서 사용자 정보 로드
        final userModel = await _userService.getUser(firebaseUser.uid);
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

      // 2. 카카오 세션 확인
      final kakaoUid = await _userService.getSavedKakaoUid();
      if (kakaoUid != null) {
        debugPrint('카카오 세션 발견: $kakaoUid');

        // 카카오 토큰 유효성 확인
        try {
          final tokenInfo = await kakao.UserApi.instance.accessTokenInfo();
          debugPrint('카카오 토큰 유효: ${tokenInfo.id}');

          // Firestore에서 사용자 정보 로드
          final userModel = await _userService.getUser(kakaoUid);
          if (userModel != null) {
            _currentUser = userModel;
            _setUserDataFromModel(userModel);
            _isLoggedIn = true;
            _isLoading = false;
            await loadHistory();
            notifyListeners();
            return true;
          }
        } catch (e) {
          debugPrint('카카오 토큰 만료: $e');
          await _userService.clearLocalSession();
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
      // Firestore에 사용자 저장/업데이트
      final userModel = await _userService.createOrUpdateUser(
        uid: uid,
        email: email,
        displayName: name,
        profileImage: profileImage,
        provider: AuthProvider.google,
      );

      // Provider 저장
      await _userService.saveProvider(AuthProvider.google);

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

      // Firestore에 사용자 저장/업데이트
      final userModel = await _userService.createOrUpdateUser(
        uid: kakaoUid,
        email: email,
        displayName: name,
        profileImage: profileImage,
        provider: AuthProvider.kakao,
      );

      // 카카오 세션 로컬 저장
      await _userService.saveKakaoSession(kakaoUid);

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

  /// 이메일 회원가입
  Future<bool> signUp(String email, String password, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Firebase Auth로 회원가입
      final userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('회원가입 실패');
      }

      final uid = userCredential.user!.uid;

      // Firestore에 사용자 저장
      final userModel = await _userService.createOrUpdateUser(
        uid: uid,
        email: email,
        displayName: name,
        provider: AuthProvider.email,
      );

      // Provider 저장
      await _userService.saveProvider(AuthProvider.email);

      _currentUser = userModel;
      _setUserDataFromModel(userModel);
      _isLoggedIn = true;
      _isLoading = false;

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? '회원가입 실패';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 이메일 로그인
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Firebase Auth로 로그인
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('로그인 실패');
      }

      final uid = userCredential.user!.uid;

      // Firestore에서 사용자 정보 로드 또는 생성
      final userModel = await _userService.createOrUpdateUser(
        uid: uid,
        email: email,
        displayName: email.split('@').first,
        provider: AuthProvider.email,
      );

      // Provider 저장
      await _userService.saveProvider(AuthProvider.email);

      _currentUser = userModel;
      _setUserDataFromModel(userModel);
      _isLoggedIn = true;
      _isLoading = false;

      await loadHistory();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? '로그인 실패';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    try {
      // Firebase Auth 로그아웃
      await _firebaseAuth.signOut();

      // Google Sign Out
      await GoogleSignIn().signOut();

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
