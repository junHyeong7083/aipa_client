import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/selection_data.dart';
import '../providers/persona_provider.dart';

class CustomPersonaScreen extends StatefulWidget {
  const CustomPersonaScreen({super.key});

  @override
  State<CustomPersonaScreen> createState() => _CustomPersonaScreenState();
}

class _CustomPersonaScreenState extends State<CustomPersonaScreen>
    with TickerProviderStateMixin {
  // 패널 수
  int _panelCount = 10;

  // 연령대 선택
  final List<String> _selectedAges = [];
  final List<String> _ageGroups = ['10대', '20대', '30대', '40대', '50대', '60대+'];

  // 성별 비율
  int _maleRatio = 50;
  int get _femaleRatio => 100 - _maleRatio;

  // 직업군 선택
  final List<String> _selectedOccupations = [];
  final List<String> _occupations = [
    '학생', '직장인', '프리랜서', '창업가', '전문직',
    '주부', 'IT', '디자이너', '마케터', '서비스업'
  ];

  // 특성 선택
  final List<String> _selectedTraits = [];
  final List<String> _traits = [
    '트렌드 민감', '가성비 중시', '프리미엄 선호', '혁신 추구',
    '보수적', '모험적', '분석적', '감성적', '실용적', '이상주의'
  ];

  // 로딩 상태
  bool _isGenerating = false;

  // 애니메이션 컨트롤러
  late AnimationController _animController;

  // 유효성 체크
  bool get _isValid => _selectedAges.isNotEmpty && _panelCount > 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  child: Column(
                    children: [
                      _buildPanelCountCard(0),
                      const SizedBox(height: 16),
                      _buildAgeGroupsCard(1),
                      const SizedBox(height: 16),
                      _buildGenderRatioCard(2),
                      const SizedBox(height: 16),
                      _buildOccupationsCard(3),
                      const SizedBox(height: 16),
                      _buildTraitsCard(4),
                      const SizedBox(height: 16),
                      if (_isValid) _buildSummaryCard(5),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isValid) _buildActionButton(),
        ],
      ),
    );
  }

  // 헤더
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 20,
        bottom: 16,
      ),
      child: Row(
        children: [
          // 뒤로가기 버튼
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.chevron_left,
                size: 28,
                color: Color(0xFF191919),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 타이틀
          const Text(
            '직접 패널 만들기',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191919),
            ),
          ),
        ],
      ),
    );
  }

  // 애니메이션 래퍼
  Widget _buildAnimatedCard(int index, Widget child) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, c) {
        final delay = index * 0.05;
        final animValue = (_animController.value - delay).clamp(0.0, 1.0 - delay) / (1.0 - delay);
        return Opacity(
          opacity: animValue.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - animValue)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  // 패널 수 카드
  Widget _buildPanelCountCard(int index) {
    final int coffeeCount = (_panelCount / 10).ceil();

    return _buildAnimatedCard(
      index,
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups, color: Color(0xFF0064FF), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      '패널 수',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191919),
                      ),
                    ),
                  ],
                ),
                Text(
                  '$_panelCount',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0064FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 슬라이더
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF0064FF),
                inactiveTrackColor: const Color(0xFFF7F8FA),
                thumbColor: const Color(0xFF0064FF),
                overlayColor: const Color(0xFF0064FF).withOpacity(0.1),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider(
                value: _panelCount.toDouble(),
                min: 1,
                max: 200,
                onChanged: (value) {
                  setState(() => _panelCount = value.round());
                },
              ),
            ),
            // 범위 표시
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1명', style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1))),
                Text('200명', style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1))),
              ],
            ),
            const SizedBox(height: 16),
            // 예상 비용
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF7F8FA))),
              ),
              child: Row(
                children: [
                  const Text('☕️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    '예상 비용: ',
                    style: TextStyle(fontSize: 14, color: Color(0xFF8B95A1)),
                  ),
                  Text(
                    '커피 $coffeeCount 잔',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF191919),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 연령대 카드
  Widget _buildAgeGroupsCard(int index) {
    return _buildAnimatedCard(
      index,
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                const Text(
                  '연령대',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191919),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF3B30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '복수 선택 가능',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1)),
            ),
            const SizedBox(height: 16),
            // 그리드
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: _ageGroups.length,
              itemBuilder: (context, idx) {
                final age = _ageGroups[idx];
                final isSelected = _selectedAges.contains(age);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedAges.remove(age);
                      } else {
                        _selectedAges.add(age);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0064FF) : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0064FF).withOpacity(0.24),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        age,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF191919),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 성별 비율 카드
  Widget _buildGenderRatioCard(int index) {
    return _buildAnimatedCard(
      index,
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '성별 비율',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191919),
              ),
            ),
            const SizedBox(height: 20),
            // 남성 슬라이더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('남성', style: TextStyle(fontSize: 14, color: Color(0xFF191919))),
                Text(
                  '$_maleRatio%',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0064FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF0064FF),
                inactiveTrackColor: const Color(0xFFF7F8FA),
                thumbColor: const Color(0xFF0064FF),
                overlayColor: const Color(0xFF0064FF).withOpacity(0.1),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider(
                value: _maleRatio.toDouble(),
                min: 0,
                max: 100,
                onChanged: (value) {
                  setState(() => _maleRatio = value.round());
                },
              ),
            ),
            const SizedBox(height: 16),
            // 여성 슬라이더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('여성', style: TextStyle(fontSize: 14, color: Color(0xFF191919))),
                Text(
                  '$_femaleRatio%',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF3B80),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFFF3B80),
                inactiveTrackColor: const Color(0xFFF7F8FA),
                thumbColor: const Color(0xFFFF3B80),
                overlayColor: const Color(0xFFFF3B80).withOpacity(0.1),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider(
                value: _femaleRatio.toDouble(),
                min: 0,
                max: 100,
                onChanged: (value) {
                  setState(() => _maleRatio = 100 - value.round());
                },
              ),
            ),
            const SizedBox(height: 20),
            // 비율 바
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    Expanded(
                      flex: _maleRatio,
                      child: Container(color: const Color(0xFF0064FF)),
                    ),
                    Expanded(
                      flex: _femaleRatio,
                      child: Container(color: const Color(0xFFFF3B80)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 직업군 카드
  Widget _buildOccupationsCard(int index) {
    return _buildAnimatedCard(
      index,
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '직업군',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191919),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '선택사항',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _occupations.map((occupation) {
                final isSelected = _selectedOccupations.contains(occupation);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedOccupations.remove(occupation);
                      } else {
                        _selectedOccupations.add(occupation);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0064FF) : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      occupation,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF4A5568),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // 특성 카드
  Widget _buildTraitsCard(int index) {
    return _buildAnimatedCard(
      index,
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '특성',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191919),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '선택사항',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _traits.map((trait) {
                final isSelected = _selectedTraits.contains(trait);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTraits.remove(trait);
                      } else {
                        _selectedTraits.add(trait);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0064FF) : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      trait,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF4A5568),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // 요약 카드
  Widget _buildSummaryCard(int index) {
    return _buildAnimatedCard(
      index,
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0064FF).withOpacity(0.05),
              const Color(0xFFFF3B80).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF0064FF).withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF0064FF), size: 20),
                const SizedBox(width: 8),
                const Text(
                  '패널 구성 요약',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191919),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('총', '$_panelCount명'),
            _buildSummaryRow('연령대', _selectedAges.join(', ')),
            _buildSummaryRow('성별', '남성 $_maleRatio%, 여성 $_femaleRatio%'),
            if (_selectedOccupations.isNotEmpty)
              _buildSummaryRow('직업', _selectedOccupations.join(', ')),
            if (_selectedTraits.isNotEmpty)
              _buildSummaryRow('특성', _selectedTraits.join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
          ),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191919),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 하단 액션 버튼
  Widget _buildActionButton() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0),
              Colors.white,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: GestureDetector(
            onTap: _handleComplete,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0064FF),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0064FF).withOpacity(0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isGenerating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '페르소나 생성 중...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '패널 생성하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // 한국어 연령대 → SelectionData 키 매핑
  String _ageToKey(String age) {
    switch (age) {
      case '10대':
        return '10s';
      case '20대':
        return '20s';
      case '30대':
        return '30s';
      case '40대':
        return '40s';
      case '50대':
        return '50s+';
      case '60대+':
        return '60s+';
      default:
        return '20s';
    }
  }

  // 완료 처리
  Future<void> _handleComplete() async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    // 선택된 연령대를 비율로 변환 (균등 배분)
    final ageRatios = <String, int>{
      '10s': 0,
      '20s': 0,
      '30s': 0,
      '40s': 0,
      '50s+': 0,
      '60s+': 0,
    };
    if (_selectedAges.isNotEmpty) {
      final ratioPerGroup = 100 ~/ _selectedAges.length;
      int remainder = 100 - (ratioPerGroup * _selectedAges.length);
      for (final age in _selectedAges) {
        final key = _ageToKey(age);
        ageRatios[key] = (ageRatios[key] ?? 0) + ratioPerGroup;
        if (remainder > 0) {
          ageRatios[key] = ageRatios[key]! + 1;
          remainder--;
        }
      }
    }

    final selection = SelectionData(
      method: 'custom',
      sampleSize: _panelCount,
      screeningRule: _selectedTraits.isNotEmpty
          ? _selectedTraits.join(', ')
          : '',
      maleRatio: _maleRatio,
      femaleRatio: _femaleRatio,
      ageRatios: ageRatios,
      occupations: List<String>.from(_selectedOccupations),
      traits: List<String>.from(_selectedTraits),
    );

    try {
      final personaProvider = context.read<PersonaProvider>();
      await personaProvider.generatePersonas(selection);

      if (!mounted) return;

      if (personaProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('페르소나 생성 중 오류가 발생했습니다: ${personaProvider.error}'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // 페르소나가 있으면 (mock 폴백 포함) 페르소나 화면으로 이동
      if (personaProvider.personas.isNotEmpty) {
        Navigator.pushNamed(context, '/persona');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('페르소나 생성 실패: $e'),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
