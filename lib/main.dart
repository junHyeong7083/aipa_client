import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'providers/selection_provider.dart';
import 'providers/persona_provider.dart';
import 'providers/survey_provider.dart';
import 'providers/user_provider.dart';

import 'screens/login_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/persona_screen.dart';
import 'screens/survey_screen.dart';
import 'screens/survey_result_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/history_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/prompt_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/custom_persona_screen.dart';
import 'screens/multi_community_screen.dart';
import 'screens/chat_history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // dotenv 로드
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('dotenv 로드 실패: $e');
  }

  // Kakao SDK 초기화
  final kakaoNativeAppKey = dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '';
  if (kakaoNativeAppKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
    debugPrint('Kakao SDK 초기화 성공');
  } else {
    debugPrint('Kakao Native App Key가 설정되지 않았습니다');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SelectionProvider()),
        ChangeNotifierProvider(create: (_) => PersonaProvider()),
        ChangeNotifierProvider(create: (_) => SurveyProvider()),
      ],
      child: MaterialApp(
        title: 'AI Research Panel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/main': (context) => const MainMenuScreen(),
          '/setup': (context) => const SetupScreen(),
          '/persona': (context) => const PersonaScreen(),
          '/survey': (context) => const SurveyScreen(),
          '/result': (context) => const SurveyResultScreen(),
          '/subscription': (context) => const SubscriptionScreen(),
          '/history': (context) => const HistoryScreen(),
          '/upload': (context) => const UploadScreen(),
          '/prompt': (context) => const PromptScreen(),
          '/chat': (context) => const ChatScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/custom-persona': (context) => const CustomPersonaScreen(),
          '/multi': (context) => const MultiCommunityScreen(),
          '/chat-history': (context) => const ChatHistoryScreen(),
        },
      ),
    );
  }
}

/// 온보딩/스플래시 화면 - 자동 로그인 체크
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isExiting = false;

  // Cubic bezier [0.16, 1, 0.3, 1] 와 유사한 커브
  static const Curve _easingCurve = Curves.easeOutExpo;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startOnboarding();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: _easingCurve),
    );

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: _easingCurve),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: _easingCurve),
    );

    // 0.2초 딜레이 후 애니메이션 시작
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  Future<void> _startOnboarding() async {
    // 2.2초 후 페이드아웃 시작
    await Future.delayed(const Duration(milliseconds: 2200));

    if (!mounted) return;

    setState(() => _isExiting = true);
    _controller.reverse();

    // 0.6초 후 다음 화면으로
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    await _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isLoggedIn = await userProvider.checkAutoLogin();

    if (!mounted) return;

    if (isLoggedIn) {
      debugPrint('자동 로그인 성공 → 메인 화면으로 이동');
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      debugPrint('자동 로그인 실패 → 로그인 화면으로 이동');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: child,
                  ),
                ),
              );
            },
            child: Text(
              '누구의 의견이 궁금하신가요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                height: 1.4,
                letterSpacing: -0.02 * 24,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
