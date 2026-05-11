import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/persona_provider.dart';
import '../models/selection_data.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  // 탭: 0 = 설문, 1 = 채팅
  int _currentTab = 0;
  late PageController _pageController;

  // 설문 탭용
  String? _selectedTemplate;
  bool _isLoading = false;

  // 애니메이션
  late AnimationController _headerController;
  late AnimationController _cardsController;
  late Animation<double> _headerOpacity;
  late Animation<Offset> _headerSlide;

  // 설문용 패널 템플릿 (연령/직업 조건 포함)
  final List<Map<String, dynamic>> _surveyTemplates = [
    {
      'id': 'consumer-mix',
      'name': '일반 소비자 믹스',
      'emoji': '👥',
      'count': 10,
      'description': '20-40대 남녀, 다양한 배경',
      'ageRatios': {'10s': 0, '20s': 30, '30s': 35, '40s': 35, '50s+': 0, '60s+': 0},
    },
    {
      'id': 'expert-panel',
      'name': '전문가 패널',
      'emoji': '🎓',
      'count': 5,
      'description': '30-50대 전문직 중심',
      'ageRatios': {'10s': 0, '20s': 0, '30s': 30, '40s': 40, '50s+': 30, '60s+': 0},
      'occupations': ['전문직', '공무원', '임원'],
    },
    {
      'id': 'young-trend',
      'name': 'MZ세대',
      'emoji': '✨',
      'count': 15,
      'description': '10-20대 트렌디한 젊은층',
      'ageRatios': {'10s': 30, '20s': 50, '30s': 20, '40s': 0, '50s+': 0, '60s+': 0},
    },
    {
      'id': 'diverse-age',
      'name': '전 연령층',
      'emoji': '🌈',
      'count': 12,
      'description': '10대부터 60대 이상까지',
      'ageRatios': {'10s': 15, '20s': 20, '30s': 20, '40s': 20, '50s+': 15, '60s+': 10},
    },
  ];

  // 로딩 메시지
  final String _loadingMessage = '페르소나 생성 중...';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _setupAnimations();
  }

  void _setupAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutExpo),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutExpo));

    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _headerController.forward();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardsController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _headerController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _isLoading ? _buildLoadingScreen() : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentTab = index;
                _selectedTemplate = null;
              });
            },
            children: [
              _buildSurveyTab(),
              _buildChatTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // 헤더
  // ═══════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      child: FadeTransition(
        opacity: _headerOpacity,
        child: SlideTransition(
          position: _headerSlide,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AIPA',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0064FF),
                ),
              ),
              GestureDetector(
                onTap: () => _showSettingsMenu(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF191919),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.menu, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 탭 바 (설문 / 채팅)
  // ═══════════════════════════════════════

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          Expanded(child: _buildTab(0, '설문 시뮬레이션', Icons.poll)),
          const SizedBox(width: 12),
          Expanded(child: _buildTab(1, 'AI 채팅', Icons.chat_bubble)),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0064FF) : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 설문 탭
  // ═══════════════════════════════════════

  Widget _buildSurveyTab() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '설문 패널을 선택하세요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF191919)),
              ),
              const SizedBox(height: 4),
              Text(
                'AI 패널이 설문에 응답합니다',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),

              // 템플릿 카드들
              ...List.generate(_surveyTemplates.length, (index) {
                return _buildSurveyTemplateCard(_surveyTemplates[index], index);
              }),
              const SizedBox(height: 12),

              // 직접 패널 만들기
              _buildCustomPanelButton(),
            ],
          ),
        ),
        if (_selectedTemplate != null) _buildSurveyActionButton(),
      ],
    );
  }

  Widget _buildSurveyTemplateCard(Map<String, dynamic> template, int index) {
    final isSelected = _selectedTemplate == template['id'];
    final int count = template['count'];

    return AnimatedBuilder(
      animation: _cardsController,
      builder: (context, child) {
        final delay = index * 0.08;
        final animValue = (_cardsController.value - delay).clamp(0.0, 1.0 - delay) / (1.0 - delay);
        return Opacity(
          opacity: animValue.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - animValue)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => setState(() => _selectedTemplate = isSelected ? null : template['id']),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? Border.all(color: const Color(0xFF0064FF), width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: isSelected ? const Color(0xFF0064FF).withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
                blurRadius: isSelected ? 16 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 이모지
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0064FF).withValues(alpha: 0.1) : const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(template['emoji'], style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 16),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFF0064FF) : const Color(0xFF191919),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template['description'],
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              // 패널 수
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0064FF) : const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${count}명',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPanelButton() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/custom-persona'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF0064FF).withValues(alpha: 0.08), const Color(0xFFFF3B80).withValues(alpha: 0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF0064FF).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0064FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.tune, color: Color(0xFF0064FF), size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('직접 패널 만들기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF191919))),
                  SizedBox(height: 2),
                  Text('나만의 맞춤 패널 구성', style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF0064FF)),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyActionButton() {
    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: GestureDetector(
        onTap: _onSurveyTemplateSelected,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF0064FF),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0064FF).withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '설문 시작하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 채팅 탭
  // ═══════════════════════════════════════

  Widget _buildChatTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '누구와 대화할까요?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF191919)),
          ),
          const SizedBox(height: 4),
          Text(
            'AI 페르소나 1명을 선택해서 대화합니다',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),

          // 기본 페르소나 카드들
          _buildChatPersonaCard(
            emoji: '🎓',
            name: 'AI 교수님',
            description: '다양한 분야의 전문 지식을 가진 교수',
            persona: {'name': 'AI 교수님', 'gender': '남성', 'age': 45, 'occupation': '대학교수', 'description': '다양한 분야의 전문 지식을 갖춘 AI 교수님', 'socialStatus': 'senior'},
          ),
          _buildChatPersonaCard(
            emoji: '👩‍💼',
            name: 'MZ 마케터',
            description: '트렌드에 민감한 20대 마케팅 전문가',
            persona: {'name': 'MZ 마케터', 'gender': '여성', 'age': 27, 'occupation': '마케터', 'description': '대기업 마케팅팀 3년차, SNS 트렌드 전문', 'socialStatus': 'junior'},
          ),
          _buildChatPersonaCard(
            emoji: '👨‍💻',
            name: 'IT 개발자',
            description: '기술 관점에서 분석하는 30대 개발자',
            persona: {'name': 'IT 개발자', 'gender': '남성', 'age': 32, 'occupation': 'IT 개발자', 'description': '스타트업 풀스택 개발자, 기술 트렌드 관심', 'socialStatus': 'junior'},
          ),
          _buildChatPersonaCard(
            emoji: '👵',
            name: '50대 주부',
            description: '가족 중심적이고 실용적인 시각',
            persona: {'name': '50대 주부', 'gender': '여성', 'age': 53, 'occupation': '주부', 'description': '자녀 2명, 알뜰 소비, 건강 관심', 'socialStatus': 'senior'},
          ),

          const SizedBox(height: 16),

          // 커스텀 페르소나 만들기
          GestureDetector(
            onTap: () => _startCustomChat(),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade50, Colors.blue.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_add, color: Colors.purple, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('직접 만들기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF191919))),
                        SizedBox(height: 2),
                        Text('원하는 페르소나를 설정해서 대화', style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.purple),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPersonaCard({
    required String emoji,
    required String name,
    required String description,
    required Map<String, dynamic> persona,
  }) {
    return GestureDetector(
      onTap: () => _startChat(persona),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF191919))),
                  const SizedBox(height: 2),
                  Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 액션
  // ═══════════════════════════════════════

  void _startChat(Map<String, dynamic> persona) {
    Navigator.pushNamed(context, '/upload', arguments: {
      'mode': 'chat',
      'persona': persona,
    });
  }

  void _startCustomChat() {
    // 채팅용 커스텀: 간단한 다이얼로그로 페르소나 설정
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ChatPersonaBuilder(
        onComplete: (persona) {
          Navigator.pop(context);
          _startChat(persona);
        },
      ),
    );
  }

  void _onSurveyTemplateSelected() async {
    if (_selectedTemplate == null) return;

    final template = _surveyTemplates.firstWhere((t) => t['id'] == _selectedTemplate);

    setState(() => _isLoading = true);

    // 페르소나 생성 API 호출 (템플릿 조건 반영)
    final personaProvider = context.read<PersonaProvider>();
    final templateAgeRatios = template['ageRatios'] as Map<String, dynamic>?;
    final templateOccupations = template['occupations'] as List<String>?;

    final selection = SelectionData(
      method: template['id'] as String,
      sampleSize: template['count'] as int,
      ageRatios: templateAgeRatios != null
          ? templateAgeRatios.map((k, v) => MapEntry(k, v as int))
          : {'10s': 10, '20s': 30, '30s': 30, '40s': 20, '50s+': 10},
      occupations: templateOccupations ?? [],
    );

    try {
      await personaProvider.generatePersonas(selection);
    } catch (e) {
      debugPrint('페르소나 생성 실패: $e');
    }

    // 로딩 완료 후 바로 이동
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushNamed(context, '/persona');
    }
  }

  // ═══════════════════════════════════════
  // 로딩 화면
  // ═══════════════════════════════════════

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0064FF)),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _loadingMessage,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // 설정 메뉴
  // ═══════════════════════════════════════

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('프로필 설정'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('히스토리'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/history');
                },
              ),
              ListTile(
                leading: const Icon(Icons.card_membership),
                title: const Text('구독 관리'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/subscription');
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade400),
                title: Text('로그아웃', style: TextStyle(color: Colors.red.shade400)),
                onTap: () async {
                  Navigator.pop(context);
                  await context.read<UserProvider>().logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════
// 채팅용 커스텀 페르소나 빌더 (바텀시트)
// ═══════════════════════════════════════

class _ChatPersonaBuilder extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;

  const _ChatPersonaBuilder({required this.onComplete});

  @override
  State<_ChatPersonaBuilder> createState() => _ChatPersonaBuilderState();
}

class _ChatPersonaBuilderState extends State<_ChatPersonaBuilder> {
  String _name = '';
  String _gender = '남성';
  int _age = 30;
  String _selectedAge = '30대';
  String _selectedOccupation = '';

  final _ageOptions = ['10대', '20대', '30대', '40대', '50대', '60대+'];

  final _occupations = ['학생', '직장인', '프리랜서', '자영업자', '주부', '전문직', '공무원', 'IT 개발자', '마케터', '디자이너'];

  final _personalities = ['보수적인', '진보적인', '소심한', '적극적인', '감성적인', '분석적인', '실용적인', '이상주의적', '모험적인', '신중한'];
  final List<String> _selectedPersonalities = [];

  final _interests = ['가성비 중시', '프리미엄 선호', '건강 관심', '트렌디', '친환경', '디지털 친숙', '브랜드 선호', 'SNS 활발', '운동 매니아', '미니멀리스트'];
  final List<String> _selectedInterests = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          // 드래그 핸들 + 타이틀
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('페르소나 만들기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 스크롤 가능한 내용
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름
                  TextField(
                    decoration: InputDecoration(
                      labelText: '이름 (선택)',
                      hintText: '예: 김철수',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (v) => _name = v,
                  ),
                  const SizedBox(height: 14),

                  // 연령대 + 성별
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedAge,
                          decoration: InputDecoration(
                            labelText: '연령대',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _ageOptions.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedAge = v);
                              _age = {'10대': 17, '20대': 25, '30대': 33, '40대': 45, '50대': 55, '60대+': 65}[v] ?? 30;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(label: const Text('남'), selected: _gender == '남성', onSelected: (_) => setState(() => _gender = '남성')),
                      const SizedBox(width: 4),
                      ChoiceChip(label: const Text('여'), selected: _gender == '여성', onSelected: (_) => setState(() => _gender = '여성')),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 직업 선택
                  const Text('직업', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _occupations.map((occ) {
                      final isSelected = _selectedOccupation == occ;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedOccupation = isSelected ? '' : occ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0064FF) : const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(occ, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : Colors.grey.shade700)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // 성격 선택
                  const Text('성격 (최대 3개)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _personalities.map((p) {
                      final isSelected = _selectedPersonalities.contains(p);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSelected) { _selectedPersonalities.remove(p); }
                          else if (_selectedPersonalities.length < 3) { _selectedPersonalities.add(p); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.purple : const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(p, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : Colors.grey.shade700)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // 관심사 선택
                  const Text('관심사 (최대 3개)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interests.map((i) {
                      final isSelected = _selectedInterests.contains(i);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSelected) { _selectedInterests.remove(i); }
                          else if (_selectedInterests.length < 3) { _selectedInterests.add(i); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.teal : const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(i, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : Colors.grey.shade700)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 하단 고정 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final traits = [..._selectedPersonalities, ..._selectedInterests];
                  final desc = traits.join(', ');
                  widget.onComplete({
                    'name': _name.isNotEmpty ? _name : '$_selectedAge $_gender',
                    'gender': _gender,
                    'age': _age,
                    'occupation': _selectedOccupation.isNotEmpty ? _selectedOccupation : '미지정',
                    'description': desc,
                    'traits': traits,
                    'socialStatus': _age >= 40 ? 'senior' : 'junior',
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0064FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('대화 시작하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
