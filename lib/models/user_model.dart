/// 사용자 인증 제공자 타입
enum AuthProvider {
  google,
  kakao,
  email,
  guest,
}

/// 백엔드(users 테이블)에 저장되는 사용자 모델.
/// 서버 응답 키: id, email, nickname, auth_method, profile_image_url,
///               interests, plan, plan_expires_at, surveys_remaining,
///               created_at, last_login_at
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? profileImage;
  final AuthProvider provider;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final List<String>? interests;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.profileImage,
    required this.provider,
    required this.createdAt,
    required this.lastLoginAt,
    this.interests,
  });

  /// 서버 JSON → UserModel
  factory UserModel.fromJson(Map<String, dynamic> data) {
    DateTime parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final method = (data['auth_method'] ?? data['provider'] ?? 'email').toString();
    return UserModel(
      uid: (data['id'] ?? data['uid'] ?? '').toString(),
      email: data['email'] ?? '',
      displayName: data['nickname'] ?? data['displayName'] ?? 'User',
      profileImage: (data['profile_image_url'] ?? data['profileImage']) as String?,
      provider: AuthProvider.values.firstWhere(
        (e) => e.name == method,
        orElse: () => AuthProvider.email,
      ),
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
      lastLoginAt: parseDate(data['last_login_at'] ?? data['lastLoginAt']),
      interests: data['interests'] != null
          ? List<String>.from(data['interests'])
          : null,
    );
  }

  /// 회원가입 요청 바디 (서버 SignupRequest 형태)
  Map<String, dynamic> toSignupJson({String? password}) {
    return {
      'id': uid,
      'email': email,
      if (password != null) 'password': password,
      'nickname': displayName,
      'auth_method': provider.name,
      'profile_image_url': profileImage ?? '',
      'interests': interests ?? [],
    };
  }

  /// 복사본 생성 (일부 필드 변경)
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? profileImage,
    AuthProvider? provider,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    List<String>? interests,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileImage: profileImage ?? this.profileImage,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      interests: interests ?? this.interests,
    );
  }
}
