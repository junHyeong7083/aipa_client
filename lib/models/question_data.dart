class TableRow {
  final String id;
  final String label;

  TableRow({required this.id, required this.label});

  factory TableRow.fromJson(Map<String, dynamic> json) {
    return TableRow(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label};
}

class QuestionData {
  final String id;
  final String question;
  final String type; // text, table, multi, unknown
  final List<String> options;
  final List<TableRow>? rows;
  final List<String>? scale;
  final bool allowMultiple;

  QuestionData({
    required this.id,
    required this.question,
    required this.type,
    this.options = const [],
    this.rows,
    this.scale,
    this.allowMultiple = false,
  });

  factory QuestionData.fromJson(Map<String, dynamic> json) {
    return QuestionData(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      type: json['type'] ?? 'unknown',
      options: List<String>.from(json['options'] ?? []),
      rows: json['rows'] != null
          ? (json['rows'] as List).map((r) => TableRow.fromJson(r)).toList()
          : null,
      scale: json['scale'] != null ? List<String>.from(json['scale']) : null,
      allowMultiple: json['allowMultiple'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'type': type,
      'options': options,
      'rows': rows?.map((r) => r.toJson()).toList(),
      'scale': scale,
      'allowMultiple': allowMultiple,
    };
  }
}

class FlattenedQuestion {
  final String id;
  final String question;
  final String type; // text, multi, table_row
  final List<String> options;

  FlattenedQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options = const [],
  });

  factory FlattenedQuestion.fromJson(Map<String, dynamic> json) {
    return FlattenedQuestion(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      type: json['type'] ?? 'text',
      options: List<String>.from(json['options'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'type': type,
      'options': options,
    };
  }
}
