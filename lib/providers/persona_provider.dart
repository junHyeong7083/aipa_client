import 'package:flutter/foundation.dart';
import '../models/persona_data.dart';
import '../models/selection_data.dart';
import '../services/api_service.dart';

class PersonaProvider extends ChangeNotifier {
  List<PersonaData> _personas = [];
  bool _isLoading = false;
  String? _error;

  List<PersonaData> get personas => _personas;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<PersonaData> get juniorPersonas =>
      _personas.where((p) => p.socialStatus == 'junior').toList();

  List<PersonaData> get seniorPersonas =>
      _personas.where((p) => p.socialStatus == 'senior').toList();

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void setPersonas(List<PersonaData> personas) {
    _personas = personas;
    _error = null;
    notifyListeners();
  }

  void addPersona(PersonaData persona) {
    _personas.add(persona);
    notifyListeners();
  }

  void clearPersonas() {
    _personas = [];
    _error = null;
    notifyListeners();
  }

  // AIPA Engine API로 페르소나 생성
  Future<void> generatePersonas(SelectionData selection) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final apiService = ApiService();
      final personas = await apiService.generatePersonas(selection);
      _personas = personas;
    } catch (e) {
      _error = e.toString();
      // API 실패 시 mock 데이터 폴백
      _personas = _getMockPersonas();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // API 연결 실패 시 폴백용 mock 데이터
  List<PersonaData> _getMockPersonas() {
    return [
      PersonaData(
        name: '김민수',
        gender: '남성',
        age: 28,
        occupation: '소프트웨어 개발자',
        description: '서울에서 스타트업에 다니는 3년차 개발자. 새로운 기술 트렌드에 관심이 많다.',
        socialStatus: 'junior',
      ),
      PersonaData(
        name: '이서연',
        gender: '여성',
        age: 25,
        occupation: '마케팅 담당자',
        description: '대기업 마케팅팀 신입. SNS 마케팅을 담당하며 트렌드에 민감하다.',
        socialStatus: 'junior',
      ),
      PersonaData(
        name: '박정훈',
        gender: '남성',
        age: 52,
        occupation: '부장',
        description: '제조업 대기업 부장. 25년 경력의 베테랑으로 조직 관리에 능숙하다.',
        socialStatus: 'senior',
      ),
      PersonaData(
        name: '최영희',
        gender: '여성',
        age: 48,
        occupation: '대학교수',
        description: '경영학과 교수. 연구와 강의를 병행하며 학계에서 인정받는 전문가.',
        socialStatus: 'senior',
      ),
    ];
  }
}
