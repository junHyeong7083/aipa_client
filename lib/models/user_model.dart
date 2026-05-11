import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 인증 제공자 타입
enum AuthProvider {
  google,
  kakao,
  email,
  guest,
}

/// Firestore에 저장되는 사용자 모델
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

  /// Firestore 문서에서 UserModel 생성
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'User',
      profileImage: data['profileImage'],
      provider: AuthProvider.values.firstWhere(
        (e) => e.name == data['provider'],
        orElse: () => AuthProvider.email,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      interests: data['interests'] != null
          ? List<String>.from(data['interests'])
          : null,
    );
  }

  /// Firestore에 저장할 Map으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'profileImage': profileImage,
      'provider': provider.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'interests': interests,
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
