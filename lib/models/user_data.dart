enum SubscriptionPlan { free, plus, pro }

class UserData {
  final String id;
  final String email;
  final String name;
  final String? profileImage;
  final SubscriptionPlan plan;
  final DateTime? planExpiresAt;
  final int surveysRemaining; // 무료 플랜용 잔여 횟수

  UserData({
    required this.id,
    required this.email,
    required this.name,
    this.profileImage,
    this.plan = SubscriptionPlan.free,
    this.planExpiresAt,
    this.surveysRemaining = 3, // 무료는 월 3회
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      profileImage: json['profileImage'],
      plan: SubscriptionPlan.values.firstWhere(
        (p) => p.name == json['plan'],
        orElse: () => SubscriptionPlan.free,
      ),
      planExpiresAt: json['planExpiresAt'] != null
          ? DateTime.parse(json['planExpiresAt'])
          : null,
      surveysRemaining: json['surveysRemaining'] ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profileImage': profileImage,
      'plan': plan.name,
      'planExpiresAt': planExpiresAt?.toIso8601String(),
      'surveysRemaining': surveysRemaining,
    };
  }

  String get planDisplayName {
    switch (plan) {
      case SubscriptionPlan.free:
        return '무료';
      case SubscriptionPlan.plus:
        return 'Plus';
      case SubscriptionPlan.pro:
        return 'Pro';
    }
  }

  String get planPrice {
    switch (plan) {
      case SubscriptionPlan.free:
        return '무료';
      case SubscriptionPlan.plus:
        return '월 4,900원';
      case SubscriptionPlan.pro:
        return '월 9,900원';
    }
  }

  bool get canRunSurvey {
    if (plan == SubscriptionPlan.free) {
      return surveysRemaining > 0;
    }
    return true;
  }

  UserData copyWith({
    String? id,
    String? email,
    String? name,
    String? profileImage,
    SubscriptionPlan? plan,
    DateTime? planExpiresAt,
    int? surveysRemaining,
  }) {
    return UserData(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImage: profileImage ?? this.profileImage,
      plan: plan ?? this.plan,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
      surveysRemaining: surveysRemaining ?? this.surveysRemaining,
    );
  }
}

class SurveyHistory {
  final String id;
  final String title;
  final DateTime createdAt;
  final int personaCount;
  final double accuracy;
  final String status; // completed, in_progress

  SurveyHistory({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.personaCount,
    required this.accuracy,
    required this.status,
  });

  factory SurveyHistory.fromJson(Map<String, dynamic> json) {
    return SurveyHistory(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      personaCount: json['personaCount'] ?? 0,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
      status: json['status'] ?? 'completed',
    );
  }

  /// 서버 저장용 JSON (POST /users/{id}/history)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'persona_count': personaCount,
      'accuracy': accuracy,
      'status': status,
    };
  }
}
