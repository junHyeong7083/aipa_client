class SelectionData {
  String method;
  int sampleSize;
  String screeningRule;
  int maleRatio;
  int femaleRatio;
  Map<String, int> ageRatios;
  List<String> occupations;
  List<String> traits;

  SelectionData({
    this.method = '',
    this.sampleSize = 10,
    this.screeningRule = '',
    this.maleRatio = 50,
    this.femaleRatio = 50,
    Map<String, int>? ageRatios,
    List<String>? occupations,
    List<String>? traits,
  }) : ageRatios = ageRatios ?? {
          '10s': 10,
          '20s': 30,
          '30s': 30,
          '40s': 20,
          '50s+': 10,
        },
       occupations = occupations ?? [],
       traits = traits ?? [];

  void setGenderRatio(int male) {
    maleRatio = male;
    femaleRatio = 100 - male;
  }

  void setAgeRatio(String ageGroup, int ratio) {
    ageRatios[ageGroup] = ratio;
    _normalizeAgeRatios();
  }

  void _normalizeAgeRatios() {
    final total = ageRatios.values.fold(0, (sum, v) => sum + v);
    if (total != 100 && total > 0) {
      final scale = 100 / total;
      ageRatios.updateAll((key, value) => (value * scale).round());
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'sampleSize': sampleSize,
      'screeningRule': screeningRule,
      'maleRatio': maleRatio,
      'femaleRatio': femaleRatio,
      'ageRatios': ageRatios,
    };
  }

  @override
  String toString() {
    return 'SelectionData(method: $method, sampleSize: $sampleSize, male: $maleRatio%, female: $femaleRatio%)';
  }
}
