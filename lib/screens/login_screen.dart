import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import '../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // 화면 상태
  String _screenState = 'login';
  bool _showEmailLogin = false;
  bool _isLoginLoading = false;
  bool _signupCompleted = false;

  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late AnimationController _logoController;
  late AnimationController _stepController;
  late AnimationController _progressController;
  late AnimationController _completeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _stepOpacityAnimation;
  late Animation<Offset> _stepSlideAnimation;
  late Animation<double> _completeScaleAnimation;

  // 폼 컨트롤러
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  // 관심분야 선택 (TS 디자인 - 8개 그리드)
  final List<String> _selectedInterests = [];
  final List<String> _interestOptions = [
    '마케팅',
    '기획',
    '개발',
    '디자인',
    '교육',
    '연구',
    '비즈니스',
    '스타트업',
  ];

  // 페르소나 템플릿 선택 (TS 디자인)
  final List<String> _selectedPersonas = [];
  final List<Map<String, String>> _personaTemplates = [
    {'id': '1', 'name': 'MZ 직장인', 'desc': '20-30대 회사원'},
    {'id': '2', 'name': '대학생', 'desc': '전공별 대학생'},
    {'id': '3', 'name': '주부', 'desc': '30-50대 가정주부'},
    {'id': '4', 'name': '시니어', 'desc': '60대 이상'},
    {'id': '5', 'name': '자영업자', 'desc': '소상공인/자영업'},
    {'id': '6', 'name': '전문직', 'desc': '의사/변호사/회계사'},
  ];

  // 현재 진행률 (애니메이션용)
  double _currentProgress = 0.0;

  // 커스텀 이징 커브 [0.16, 1, 0.3, 1]
  static const Curve _easingCurve = Curves.easeOutExpo;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // 메인 페이드 애니메이션
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: _easingCurve),
    );

    // 로고 애니메이션
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _logoScaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: _easingCurve),
    );
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: _easingCurve),
    );

    // 버튼 슬라이드 애니메이션
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: _easingCurve));

    // 스텝 전환 애니메이션 (x: 20 → 0, opacity: 0 → 1)
    _stepController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _stepOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _stepController, curve: _easingCurve),
    );
    _stepSlideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0), // x: 20px offset
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _stepController, curve: _easingCurve));

    // 프로그레스 바 애니메이션
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 완료 화면 스프링 애니메이션
    _completeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _completeScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _completeController,
        curve: Curves.elasticOut, // 스프링 효과
      ),
    );

    // 애니메이션 시작
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _logoController.forward();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _logoController.dispose();
    _stepController.dispose();
    _progressController.dispose();
    _completeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildCurrentScreen(),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_screenState) {
      case 'login':
        return _buildLoginScreen();
      case 'account':
        return _buildAccountScreen();
      case 'interests':
        return _buildInterestsScreen();
      case 'personas':
        return _buildPersonasScreen();
      case 'complete':
        return _buildCompleteScreen();
      // 기존 호환성 유지
      case 'signup1':
        return _buildAccountScreen();
      case 'signup2':
        return _buildInterestsScreen();
      case 'signup3':
        return _buildCompleteScreen();
      default:
        return _buildLoginScreen();
    }
  }

  // 로그인 화면 (TS 디자인 적용)
  Widget _buildLoginScreen() {
    return Padding(
      key: const ValueKey('login'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          // 상단 로고 및 멘트
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고 애니메이션
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacityAnimation.value,
                      child: Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0064FF).withOpacity(0.12),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // 메인 문구
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: const Text(
                      '커피 한 잔으로 생각을 읽다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF191919),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 하단 로그인 옵션
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _showEmailLogin
                  ? _buildEmailLoginForm()
                  : _buildSocialLoginOptions(),
            ),
          ),
        ],
      ),
    );
  }

  // 소셜 로그인 옵션들
  Widget _buildSocialLoginOptions() {
    return Column(
      children: [
        if (_isLoginLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Color(0xFF0064FF),
                strokeWidth: 2.5,
              ),
            ),
          ),
        // Google 로그인
        _buildLoginButton(
          onTap: _isLoginLoading ? () {} : () => _socialLogin('google'),
          backgroundColor: Colors.white,
          borderColor: const Color(0xFFE8EBED),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGoogleIcon(),
              const SizedBox(width: 12),
              const Text(
                'Google로 계속하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191919),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 카카오 로그인
        _buildLoginButton(
          onTap: _isLoginLoading ? () {} : () => _socialLogin('kakao'),
          backgroundColor: const Color(0xFFFEE500),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKakaoIcon(),
              const SizedBox(width: 12),
              const Text(
                '카카오톡으로 계속하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191919),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // "또는" 구분선
        Row(
          children: [
            Expanded(child: Container(height: 1, color: const Color(0xFFE8EBED))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '또는',
                style: TextStyle(fontSize: 14, color: Color(0xFF8B95A1)),
              ),
            ),
            Expanded(child: Container(height: 1, color: const Color(0xFFE8EBED))),
          ],
        ),
        const SizedBox(height: 24),

        // 이메일로 로그인
        _buildLoginButton(
          onTap: () => setState(() => _showEmailLogin = true),
          backgroundColor: Colors.white,
          borderColor: const Color(0xFFE8EBED),
          child: const Text(
            '이메일로 로그인',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191919),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 이메일로 가입하기
        _buildLoginButton(
          onTap: () => _goToStep('account'),
          backgroundColor: const Color(0xFF0064FF),
          shadowColor: const Color(0xFF0064FF).withOpacity(0.24),
          child: const Text(
            '이메일로 가입하기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // 이메일 로그인 폼
  Widget _buildEmailLoginForm() {
    return Column(
      children: [
        // 이메일 입력
        _buildTextField(
          controller: _emailController,
          hintText: '이메일',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),

        // 비밀번호 입력
        _buildTextField(
          controller: _passwordController,
          hintText: '비밀번호',
          icon: Icons.lock_outline,
          obscureText: _obscurePassword,
          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 16),

        // 로그인 버튼
        _buildLoginButton(
          onTap: _isLoginLoading ? () {} : _emailLogin,
          backgroundColor: const Color(0xFF0064FF),
          shadowColor: const Color(0xFF0064FF).withOpacity(0.24),
          child: _isLoginLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  '로그인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 12),

        // 다른 방법으로 로그인
        TextButton(
          onPressed: () => setState(() => _showEmailLogin = false),
          child: const Text(
            '다른 방법으로 로그인',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF8B95A1),
            ),
          ),
        ),
      ],
    );
  }

  // 공통 로그인 버튼
  Widget _buildLoginButton({
    required VoidCallback onTap,
    required Color backgroundColor,
    required Widget child,
    Color? borderColor,
    Color? shadowColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          boxShadow: [
            BoxShadow(
              color: shadowColor ?? Colors.black.withOpacity(0.04),
              blurRadius: shadowColor != null ? 8 : 2,
              offset: Offset(0, shadowColor != null ? 2 : 1),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  // 텍스트 필드
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF8B95A1)),
          prefixIcon: Icon(icon, color: const Color(0xFF8B95A1), size: 20),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF8B95A1),
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0064FF)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  // Google 아이콘
  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }

  // 카카오 아이콘
  Widget _buildKakaoIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Color(0xFF191919),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.chat_bubble,
        size: 12,
        color: Color(0xFFFEE500),
      ),
    );
  }

  // ========== 스텝 전환 헬퍼 ==========
  void _goToStep(String step) {
    _stepController.reset();

    // 프로그레스 업데이트 (3단계: 33% → 66% → 100%)
    double targetProgress = 0.33;
    switch (step) {
      case 'account':
        targetProgress = 0.33; // Step 1/3
        break;
      case 'interests':
        targetProgress = 0.66; // Step 2/3
        break;
      case 'personas':
        targetProgress = 1.0; // Step 3/3
        break;
      case 'complete':
        targetProgress = 1.0;
        break;
    }

    setState(() {
      _screenState = step;
      _currentProgress = targetProgress; // 즉시 프로그레스 설정
    });

    // 스텝 진입 애니메이션
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _stepController.forward();
    });

    // 완료 화면 스프링 애니메이션
    if (step == 'complete') {
      _completeController.reset();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _completeController.forward();
      });
    }
  }

  void _animateProgress(double target) {
    final start = _currentProgress;
    final tween = Tween<double>(begin: start, end: target);

    _progressController.reset();
    _progressController.addListener(() {
      setState(() {
        _currentProgress = tween.evaluate(_progressController);
      });
    });
    _progressController.forward();
  }

  // ========== 회원가입 Step 1: Account ==========
  Widget _buildAccountScreen() {
    return FadeTransition(
      key: const ValueKey('account'),
      opacity: _stepOpacityAnimation,
      child: SlideTransition(
        position: _stepSlideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // 뒤로가기
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF191919)),
                onPressed: () => setState(() => _screenState = 'login'),
              ),
              const SizedBox(height: 24),

              // 프로그레스 바
              _buildAnimatedProgressBar(),
              const SizedBox(height: 40),

              // 타이틀
              const Text(
                '계정 만들기',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191919),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '이메일과 비밀번호를 입력해주세요',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8B95A1),
                ),
              ),
              const SizedBox(height: 32),

              // 이름 입력
              _buildTextField(
                controller: _nameController,
                hintText: '이름',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),

              // 이메일 입력
              _buildTextField(
                controller: _emailController,
                hintText: '이메일',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              // 비밀번호 입력
              _buildTextField(
                controller: _passwordController,
                hintText: '비밀번호',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 12),

              // 비밀번호 확인
              _buildTextField(
                controller: _passwordConfirmController,
                hintText: '비밀번호 확인',
                icon: Icons.lock_outline,
                obscureText: _obscurePasswordConfirm,
                onToggleObscure: () => setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
              ),
              const SizedBox(height: 40),

              // 다음 버튼
              _buildLoginButton(
                onTap: _validateAndGoToInterests,
                backgroundColor: const Color(0xFF0064FF),
                shadowColor: const Color(0xFF0064FF).withOpacity(0.24),
                child: const Text(
                  '다음',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 회원가입 Step 2: Interests (그리드 레이아웃) ==========
  Widget _buildInterestsScreen() {
    return FadeTransition(
      key: const ValueKey('interests'),
      opacity: _stepOpacityAnimation,
      child: SlideTransition(
        position: _stepSlideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // 뒤로가기
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF191919)),
                onPressed: () => _goToStep('account'),
              ),
              const SizedBox(height: 24),

              // 프로그레스 바
              _buildAnimatedProgressBar(),
              const SizedBox(height: 40),

              // 타이틀
              const Text(
                '관심 분야',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191919),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '맞춤 페르소나 추천을 위해 선택해주세요',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8B95A1),
                ),
              ),
              const SizedBox(height: 32),

              // 그리드 레이아웃 (2열)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: _interestOptions.length,
                itemBuilder: (context, index) {
                  return _buildInterestChip(_interestOptions[index]);
                },
              ),
              const SizedBox(height: 40),

              // 다음 버튼
              _buildLoginButton(
                onTap: () => _goToStep('personas'),
                backgroundColor: const Color(0xFF0064FF),
                shadowColor: const Color(0xFF0064FF).withOpacity(0.24),
                child: const Text(
                  '다음',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),

              // 건너뛰기
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => _goToStep('personas'),
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF8B95A1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 회원가입 Step 3: Personas ==========
  Widget _buildPersonasScreen() {
    return FadeTransition(
      key: const ValueKey('personas'),
      opacity: _stepOpacityAnimation,
      child: SlideTransition(
        position: _stepSlideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // 뒤로가기
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF191919)),
                onPressed: () => _goToStep('interests'),
              ),
              const SizedBox(height: 24),

              // 프로그레스 바
              _buildAnimatedProgressBar(),
              const SizedBox(height: 40),

              // 타이틀
              const Text(
                '페르소나 선택',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191919),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '자주 사용할 페르소나를 선택해주세요',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8B95A1),
                ),
              ),
              const SizedBox(height: 32),

              // 페르소나 리스트
              ..._personaTemplates.map((persona) => _buildPersonaItem(persona)),

              const SizedBox(height: 40),

              // 완료 버튼
              _buildLoginButton(
                onTap: () => _goToStep('complete'),
                backgroundColor: const Color(0xFF0064FF),
                shadowColor: const Color(0xFF0064FF).withOpacity(0.24),
                child: const Text(
                  '완료',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),

              // 건너뛰기
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => _goToStep('complete'),
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF8B95A1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 회원가입 Step 4: Complete (스프링 애니메이션) ==========
  Widget _buildCompleteScreen() {
    // 2초 후 회원가입 완료 처리 (rebuild 시 중복 실행 방지)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _screenState == 'complete' && !_signupCompleted) {
        _signupCompleted = true;
        _completeSignup();
      }
    });

    return Center(
      key: const ValueKey('complete'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: AnimatedBuilder(
          animation: _completeController,
          builder: (context, child) {
            return Opacity(
              opacity: _completeController.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _completeScaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 체크 아이콘 (스프링 효과)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF0064FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 56,
                  color: Color(0xFF0064FF),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                '가입 완료!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191919),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '이제 당신을 위한\n패널들이 준비되었습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF8B95A1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 애니메이션 프로그레스 바
  Widget _buildAnimatedProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 프로그레스 바
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EBED),
            borderRadius: BorderRadius.circular(2),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: _easingCurve,
                    width: constraints.maxWidth * _currentProgress,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0064FF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 진행률 텍스트
        Text(
          '${(_currentProgress * 100).toInt()}%',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8B95A1),
          ),
        ),
      ],
    );
  }

  // 관심분야 칩 (그리드용)
  Widget _buildInterestChip(String interest) {
    final isSelected = _selectedInterests.contains(interest);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedInterests.remove(interest);
          } else {
            _selectedInterests.add(interest);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0064FF).withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF0064FF) : const Color(0xFFE8EBED),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check, color: Color(0xFF0064FF), size: 18),
                const SizedBox(width: 6),
              ],
              Text(
                interest,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF0064FF) : const Color(0xFF191919),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 페르소나 아이템 (체크박스 스타일)
  Widget _buildPersonaItem(Map<String, String> persona) {
    final isSelected = _selectedPersonas.contains(persona['id']);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedPersonas.remove(persona['id']);
          } else {
            _selectedPersonas.add(persona['id']!);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0064FF).withOpacity(0.05) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF0064FF) : const Color(0xFFE8EBED),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // 체크박스
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0064FF) : Colors.white,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0064FF) : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 14),
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    persona['name']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF0064FF) : const Color(0xFF191919),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    persona['desc']!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8B95A1),
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

  // ========== 백엔드 로직 (기존 유지) ==========

  void _validateAndGoToInterests() {
    if (_nameController.text.trim().isEmpty) {
      _showError('이름을 입력해주세요');
      return;
    }
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      _showError('유효한 이메일을 입력해주세요');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showError('비밀번호는 6자 이상이어야 합니다');
      return;
    }
    if (_passwordController.text != _passwordConfirmController.text) {
      _showError('비밀번호가 일치하지 않습니다');
      return;
    }
    _goToStep('interests');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _emailLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요');
      return;
    }

    setState(() => _isLoginLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final success = await userProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      } else if (mounted) {
        _showError(userProvider.error ?? '로그인 실패');
      }
    } catch (e) {
      if (mounted) {
        _showError('로그인 중 오류가 발생했습니다');
      }
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
    }
  }

  Future<void> _completeSignup() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final name = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : _emailController.text.split('@').first;

      final success = await userProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        name,
      );

      if (success && mounted) {
        if (_selectedInterests.isNotEmpty) {
          await userProvider.updateInterests(_selectedInterests);
        }
        // TODO: Save _selectedPersonas to Firestore when persona preferences feature is implemented
        // e.g., await userProvider.updatePersonaPreferences(_selectedPersonas);
        Navigator.pushReplacementNamed(context, '/main');
      } else if (mounted) {
        _showError(userProvider.error ?? '회원가입 실패');
        _goToStep('account');
      }
    } catch (e) {
      if (mounted) {
        _showError('회원가입 중 오류가 발생했습니다');
        _goToStep('account');
      }
    }
  }

  Future<void> _socialLogin(String provider) async {
    setState(() => _isLoginLoading = true);
    try {
      if (provider == 'google') {
        await _signInWithGoogle();
      } else if (provider == 'kakao') {
        await _signInWithKakao();
      }
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      // Firebase 없이 Google SDK 로 계정 정보만 획득 → 서버에 등록
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // 사용자가 취소

      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final success = await userProvider.loginWithGoogle(
          'google_${googleUser.id}',
          googleUser.email,
          googleUser.displayName ?? 'User',
          profileImage: googleUser.photoUrl,
        );
        debugPrint('Google 로그인 결과: $success, user: ${userProvider.currentUser?.displayName}');
        if (success && mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        } else if (mounted) {
          _showError('Google 로그인 실패: ${userProvider.error}');
        }
      }
    } catch (e) {
      debugPrint('Google 로그인 에러: $e');
      if (mounted) _showError('로그인 중 오류: $e');
    }
  }

  Future<void> _signInWithKakao() async {
    try {
      kakao.OAuthToken token;
      if (await kakao.isKakaoTalkInstalled()) {
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      kakao.User kakaoUser = await kakao.UserApi.instance.me();

      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final success = await userProvider.loginWithKakao(
          kakaoUser.id.toString(),
          kakaoUser.kakaoAccount?.email ?? '',
          kakaoUser.kakaoAccount?.profile?.nickname ?? 'User',
          profileImage: kakaoUser.kakaoAccount?.profile?.profileImageUrl,
        );
        debugPrint('카카오 로그인 결과: $success, user: ${userProvider.currentUser?.displayName}');
        if (success && mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        } else if (mounted) {
          _showError('카카오 로그인 실패: ${userProvider.error}');
        }
      }
    } catch (e) {
      debugPrint('카카오 로그인 에러: $e');
      if (mounted) _showError('카카오 로그인 중 오류: $e');
    }
  }
}

// Google 아이콘 커스텀 페인터
class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -0.5,
      1.5,
      true,
      paint,
    );

    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      1.0,
      1.0,
      true,
      paint,
    );

    // Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      2.0,
      1.0,
      true,
      paint,
    );

    // Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      3.0,
      1.0,
      true,
      paint,
    );

    // White center
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.35,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
