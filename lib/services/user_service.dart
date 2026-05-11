import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/user_data.dart';

/// Firestore 사용자 관리 서비스
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // SharedPreferences 키
  static const String _kakaoUidKey = 'kakao_uid';
  static const String _providerKey = 'auth_provider';

  /// 사용자 조회 (uid로)
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('UserService.getUser error: $e');
      return null;
    }
  }

  /// 사용자 생성 또는 업데이트
  /// - 신규 사용자: 문서 생성
  /// - 기존 사용자: lastLoginAt 업데이트
  Future<UserModel> createOrUpdateUser({
    required String uid,
    required String email,
    required String displayName,
    String? profileImage,
    required AuthProvider provider,
    List<String>? interests,
  }) async {
    try {
      final docRef = _firestore.collection(_collection).doc(uid);
      final doc = await docRef.get();

      if (doc.exists) {
        // 기존 사용자: lastLoginAt만 업데이트
        await docRef.update({
          'lastLoginAt': Timestamp.fromDate(DateTime.now()),
        });
        return UserModel.fromFirestore(await docRef.get());
      } else {
        // 신규 사용자: 문서 생성
        final now = DateTime.now();
        final newUser = UserModel(
          uid: uid,
          email: email,
          displayName: displayName,
          profileImage: profileImage,
          provider: provider,
          createdAt: now,
          lastLoginAt: now,
          interests: interests,
        );

        await docRef.set(newUser.toFirestore());
        return newUser;
      }
    } catch (e) {
      debugPrint('UserService.createOrUpdateUser error: $e');
      rethrow;
    }
  }

  /// 사용자 관심사 업데이트
  Future<void> updateInterests(String uid, List<String> interests) async {
    try {
      await _firestore.collection(_collection).doc(uid).update({
        'interests': interests,
      });
    } catch (e) {
      debugPrint('UserService.updateInterests error: $e');
      rethrow;
    }
  }

  /// 사용자 이름 업데이트
  Future<void> updateDisplayName(String uid, String displayName) async {
    try {
      await _firestore.collection(_collection).doc(uid).update({
        'displayName': displayName,
      });
    } catch (e) {
      debugPrint('UserService.updateDisplayName error: $e');
      rethrow;
    }
  }

  /// 사용자 프로필 이미지 업데이트
  Future<void> updateProfileImage(String uid, String? profileImage) async {
    try {
      await _firestore.collection(_collection).doc(uid).update({
        'profileImage': profileImage,
      });
    } catch (e) {
      debugPrint('UserService.updateProfileImage error: $e');
      rethrow;
    }
  }

  /// 사용자 삭제
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(_collection).doc(uid).delete();
    } catch (e) {
      debugPrint('UserService.deleteUser error: $e');
      rethrow;
    }
  }

  // ============ 설문 히스토리 관리 ============

  /// Firestore에 설문 결과 저장
  Future<void> saveSurveyHistory(String userId, SurveyHistory history) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('survey_history')
          .doc(history.id)
          .set({
        'title': history.title,
        'createdAt': Timestamp.fromDate(history.createdAt),
        'personaCount': history.personaCount,
        'accuracy': history.accuracy,
        'status': history.status,
      });
    } catch (e) {
      debugPrint('UserService.saveSurveyHistory error: $e');
      rethrow;
    }
  }

  /// Firestore에서 설문 히스토리 로드
  Future<List<SurveyHistory>> loadSurveyHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('survey_history')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snapshot.docs
          .map((doc) => SurveyHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('UserService.loadSurveyHistory error: $e');
      return [];
    }
  }

  // ============ 로컬 세션 관리 (카카오용) ============

  /// 카카오 세션 저장
  Future<void> saveKakaoSession(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kakaoUidKey, uid);
    await prefs.setString(_providerKey, AuthProvider.kakao.name);
  }

  /// 저장된 카카오 세션 조회
  Future<String?> getSavedKakaoUid() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString(_providerKey);
    if (provider == AuthProvider.kakao.name) {
      return prefs.getString(_kakaoUidKey);
    }
    return null;
  }

  /// 로컬 세션 삭제 (로그아웃 시)
  Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kakaoUidKey);
    await prefs.remove(_providerKey);
  }

  /// 저장된 인증 제공자 조회
  Future<AuthProvider?> getSavedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString(_providerKey);
    if (provider != null) {
      return AuthProvider.values.firstWhere(
        (e) => e.name == provider,
        orElse: () => AuthProvider.email,
      );
    }
    return null;
  }

  /// 인증 제공자 저장
  Future<void> saveProvider(AuthProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider.name);
  }
}
