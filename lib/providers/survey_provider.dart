import 'package:flutter/foundation.dart';
import '../models/question_data.dart';
import '../models/survey_response.dart';

class SurveyProvider extends ChangeNotifier {
  List<QuestionData> _questions = [];
  List<FlattenedQuestion> _flattenedQuestions = [];
  Map<String, List<SurveyResponse>> _results = {};
  bool _isLoading = false;
  double _progress = 0.0;
  String? _error;
  String _statusMessage = '';
  String? _pdfPath;
  String? _pdfName;
  Map<String, dynamic>? _simulationResult;
  String? _activeSessionId;
  bool _isSimulationRunning = false;

  List<QuestionData> get questions => _questions;
  List<FlattenedQuestion> get flattenedQuestions => _flattenedQuestions;
  Map<String, List<SurveyResponse>> get results => _results;
  bool get isLoading => _isLoading;
  double get progress => _progress;
  String? get error => _error;
  String get statusMessage => _statusMessage;
  String? get pdfPath => _pdfPath;
  String? get pdfName => _pdfName;
  Map<String, dynamic>? get simulationResult => _simulationResult;
  String? get activeSessionId => _activeSessionId;
  bool get isSimulationRunning => _isSimulationRunning;

  void setActiveSession(String? id) {
    _activeSessionId = id;
    _isSimulationRunning = id != null;
    notifyListeners();
  }

  int get totalResponses {
    int count = 0;
    for (var responses in _results.values) {
      count += responses.length;
    }
    return count;
  }

  void setQuestions(List<QuestionData> questions) {
    _questions = questions;
    notifyListeners();
  }

  void setFlattenedQuestions(List<FlattenedQuestion> questions) {
    _flattenedQuestions = questions;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setProgress(double progress) {
    _progress = progress;
    notifyListeners();
  }

  void setStatusMessage(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void addResult(String category, SurveyResponse response) {
    if (!_results.containsKey(category)) {
      _results[category] = [];
    }
    _results[category]!.add(response);
    notifyListeners();
  }

  void setSimulationResult(Map<String, dynamic>? result) {
    _simulationResult = result;
    notifyListeners();
  }

  void setPdfFile(String? path, String? name) {
    _pdfPath = path;
    _pdfName = name;
    notifyListeners();
  }

  void clearResults() {
    _results = {};
    _progress = 0.0;
    _error = null;
    _statusMessage = '';
    notifyListeners();
  }

  void reset() {
    _questions = [];
    _flattenedQuestions = [];
    _results = {};
    _isLoading = false;
    _progress = 0.0;
    _error = null;
    _statusMessage = '';
    _pdfPath = null;
    _pdfName = null;
    _simulationResult = null;
    _activeSessionId = null;
    _isSimulationRunning = false;
    notifyListeners();
  }
}
