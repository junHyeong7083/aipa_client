import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/question_data.dart';
import '../models/survey_response.dart';

class CsvExportService {
  /// Exports survey results to a CSV file.
  /// Returns the file path on success.
  static Future<String> exportSurveyResults(
    List<FlattenedQuestion> questions,
    Map<String, List<SurveyResponse>> results,
  ) async {
    // Build header row
    final header = [
      '페르소나',
      ...questions.map((q) => q.question),
    ];

    // Build data rows: one row per SurveyResponse
    final dataRows = <List<String>>[];
    for (final responses in results.values) {
      for (final response in responses) {
        final row = <String>[response.personaName];
        for (final question in questions) {
          final match = response.answers.where((a) => a.id == question.id);
          row.add(match.isNotEmpty ? match.first.answer : '');
        }
        dataRows.add(row);
      }
    }

    final csvData = const ListToCsvConverter().convert([header, ...dataRows]);

    // Save to documents directory
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/survey_results_$timestamp.csv');
    await file.writeAsString('\uFEFF$csvData'); // BOM for Excel Korean support

    return file.path;
  }
}
