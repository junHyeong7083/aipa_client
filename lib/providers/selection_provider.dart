import 'package:flutter/foundation.dart';
import '../models/selection_data.dart';

class SelectionProvider extends ChangeNotifier {
  SelectionData _selection = SelectionData();

  SelectionData get selection => _selection;

  // 연구 방법/분야
  void setMethod(String method) {
    _selection.method = method;
    notifyListeners();
  }

  // 샘플 수
  void setSampleSize(int size) {
    _selection.sampleSize = size;
    notifyListeners();
  }

  // 스크리닝 규칙
  void setScreeningRule(String rule) {
    _selection.screeningRule = rule;
    notifyListeners();
  }

  // 성별 비율 (남성 비율 입력 시 여성은 자동 계산)
  void setGenderRatio(int maleRatio) {
    _selection.setGenderRatio(maleRatio);
    notifyListeners();
  }

  // 연령대별 비율
  void setAgeRatio(String ageGroup, int ratio) {
    _selection.setAgeRatio(ageGroup, ratio);
    notifyListeners();
  }

  // 전체 리셋
  void reset() {
    _selection = SelectionData();
    notifyListeners();
  }

  // 유효성 검사
  bool isValid() {
    return _selection.method.isNotEmpty &&
        _selection.sampleSize > 0 &&
        _selection.maleRatio >= 0 &&
        _selection.maleRatio <= 100;
  }
}
