class AnswerData {
  final String id;
  final String answer;

  AnswerData({required this.id, required this.answer});

  factory AnswerData.fromJson(Map<String, dynamic> json) {
    return AnswerData(
      id: json['id'] ?? '',
      answer: json['answer'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'answer': answer};
}

class SurveyResponse {
  final String personaName;
  final List<AnswerData> answers;
  final DateTime timestamp;

  SurveyResponse({
    required this.personaName,
    required this.answers,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SurveyResponse.fromJson(Map<String, dynamic> json) {
    return SurveyResponse(
      personaName: json['persona'] ?? '',
      answers: (json['answers'] as List?)
              ?.map((a) => AnswerData.fromJson(a))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'persona': personaName,
      'answers': answers.map((a) => a.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
