import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/user_data.dart';

/// 사용자 관리 서비스 (Firestore → PostgreSQL 백엔드 HTTP)
///
/// 서버: GET/POST /api/v1/users, /users/login, /users/{id}, /users/{id}/history
/// 쓰기(PUT/DELETE/POST history)는 공유 Bearer 토큰 헤더 필요.
class UserService {
  final _client = http.Client();

  // SharedPreferences 키 (로컬 세션 = 자동 로그인용)
  static const String _uidKey = 'auth_uid';
  static const String _providerKey = 'auth_provider';
  // 하위호환: 이전 카카오 전용 키
  static const String _kakaoUidKey = 'kakao_uid';

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (ApiConfig.bearerToken.isNotEmpty)
          'Authorization': 'Bearer ${ApiConfig.bearerToken}',
      };

  String _userUrl(String uid) => '${ApiConfig.usersUrl}/$uid';

  /// 사용자 조회 (없으면 null)
  Future<UserModel?> getUser(String uid) async {
    try {
      final res = await _client
          .get(Uri.parse(_userUrl(uid)), headers: _jsonHeaders)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is! Map || body['data'] is! Map) return null;
      return UserModel.fromJson(Map<String, dynamic>.from(body['data']));
    } catch (e) {
      debugPrint('UserService.getUser error: $e');
      return null;
    }
  }

  /// 사용자 생성 또는 업데이트 (OAuth/일반 공통)
  /// - 존재하면 last_login_at 갱신 후 최신 정보 반환
  /// - 없으면 회원가입(POST) 후 반환
  Future<UserModel> createOrUpdateUser({
    required String uid,
    required String email,
    required String displayName,
    String? profileImage,
    required AuthProvider provider,
    List<String>? interests,
    String? password, // local 가입 시에만
  }) async {
    // 1) 이미 있으면 로그인 시각만 갱신
    final existing = await getUser(uid);
    if (existing != null) {
      await _touchLastLogin(uid);
      return existing;
    }

    // 2) 신규 → 회원가입
    final model = UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      profileImage: profileImage,
      provider: provider,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      interests: interests,
    );
    final res = await _client
        .post(Uri.parse('${ApiConfig.usersUrl}/'),
            headers: _jsonHeaders,
            body: jsonEncode(model.toSignupJson(password: password)))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 201 || res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return UserModel.fromJson(Map<String, dynamic>.from(body['data']));
    }
    if (res.statusCode == 409) {
      // 이미 가입된 이메일 → 조회로 폴백
      final again = await getUser(uid);
      if (again != null) return again;
    }
    throw Exception('회원 생성 실패: ${res.statusCode} ${res.body}');
  }

  /// 이메일/비밀번호 로그인 (local 계정)
  Future<UserModel> loginLocal(String email, String password) async {
    final res = await _client
        .post(Uri.parse('${ApiConfig.usersUrl}/login'),
            headers: _jsonHeaders,
            body: jsonEncode({'email': email, 'password': password}))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      String msg = '로그인 실패';
      try {
        msg = (jsonDecode(res.body)['detail'] ?? msg).toString();
      } catch (_) {}
      throw Exception(msg);
    }
    final body = jsonDecode(res.body);
    return UserModel.fromJson(Map<String, dynamic>.from(body['data']));
  }

  Future<void> _touchLastLogin(String uid) async {
    try {
      await _client
          .put(Uri.parse(_userUrl(uid)),
              headers: _authHeaders,
              body: jsonEncode({'last_login_at': DateTime.now().toIso8601String()}))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('UserService._touchLastLogin error (무시): $e');
    }
  }

  Future<void> _updateField(String uid, Map<String, dynamic> fields) async {
    final res = await _client
        .put(Uri.parse(_userUrl(uid)),
            headers: _authHeaders, body: jsonEncode(fields))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('업데이트 실패: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> updateInterests(String uid, List<String> interests) =>
      _updateField(uid, {'interests': interests});

  Future<void> updateDisplayName(String uid, String displayName) =>
      _updateField(uid, {'nickname': displayName});

  Future<void> updateProfileImage(String uid, String? profileImage) =>
      _updateField(uid, {'profile_image_url': profileImage ?? ''});

  /// 회원 탈퇴
  Future<void> deleteUser(String uid) async {
    final res = await _client
        .delete(Uri.parse(_userUrl(uid)), headers: _authHeaders)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('회원 탈퇴 실패: ${res.statusCode}');
    }
  }

  // ============ 설문 히스토리 ============

  Future<void> saveSurveyHistory(String userId, SurveyHistory history) async {
    final res = await _client
        .post(Uri.parse('${_userUrl(userId)}/history'),
            headers: _authHeaders, body: jsonEncode(history.toJson()))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('히스토리 저장 실패: ${res.statusCode}');
    }
  }

  Future<List<SurveyHistory>> loadSurveyHistory(String userId) async {
    try {
      final res = await _client
          .get(Uri.parse('${_userUrl(userId)}/history?limit=50'),
              headers: _jsonHeaders)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final data = (body is Map ? body['data'] : null);
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((j) => SurveyHistory.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      debugPrint('UserService.loadSurveyHistory error: $e');
      return [];
    }
  }

  // ============ 로컬 세션 (자동 로그인) ============

  /// 로그인 성공 시 uid + provider 저장 (모든 provider 공통)
  Future<void> saveSession(String uid, AuthProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, uid);
    await prefs.setString(_providerKey, provider.name);
  }

  /// 저장된 uid (없으면 하위호환 카카오 키 확인)
  Future<String?> getSavedUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_uidKey) ?? prefs.getString(_kakaoUidKey);
  }

  Future<AuthProvider?> getSavedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString(_providerKey);
    if (p == null) return null;
    return AuthProvider.values.firstWhere(
      (e) => e.name == p,
      orElse: () => AuthProvider.email,
    );
  }

  Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
    await prefs.remove(_providerKey);
    await prefs.remove(_kakaoUidKey);
  }

  // 하위호환 별칭 (기존 호출부 보호)
  Future<void> saveKakaoSession(String uid) => saveSession(uid, AuthProvider.kakao);
  Future<String?> getSavedKakaoUid() async {
    final provider = await getSavedProvider();
    if (provider == AuthProvider.kakao) return getSavedUid();
    return null;
  }

  Future<void> saveProvider(AuthProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider.name);
  }
}
