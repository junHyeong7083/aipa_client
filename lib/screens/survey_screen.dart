import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_data.dart';
import '../providers/persona_provider.dart';
import '../providers/survey_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  bool _isRunning = false;
  bool _disposed = false;
  int _currentStep = 0;
  final List<String> _steps = [
    'PDF 파싱 중...',
    '설문 구조화 중...',
    '일반 GPT 응답 생성 중...',
    '페르소나 응답 생성 중...',
    '결과 분석 중...',
  ];

  @override
  void initState() {
    super.initState();
    // 첫 빌드 중 Provider 상태 변경(notifyListeners)으로 인한
    // "setState during build" 예외 방지를 위해 프레임 이후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startSurveySimulation();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _startSurveySimulation() async {
    final surveyProvider = context.read<SurveyProvider>();
    final apiService = ApiService();

    // 이미 실행 중인 세션이 있으면 이어서 폴링 (백그라운드 복귀 시)
    if (surveyProvider.activeSessionId != null && surveyProvider.isSimulationRunning) {
      setState(() {
        _isRunning = true;
        _currentStep = 4;
      });
      await _pollSession(surveyProvider, apiService, surveyProvider.activeSessionId!);
      return;
    }

    // 이미 결과가 있으면 바로 결과 화면으로
    if (surveyProvider.simulationResult != null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/result');
      return;
    }

    // 새 시뮬레이션 시작 - 이전 상태 초기화
    surveyProvider.clearResults();
    surveyProvider.setSimulationResult(null);
    surveyProvider.setActiveSession(null);

    setState(() => _isRunning = true);

    try {
      // Step 1: PDF 파싱
      setState(() => _currentStep = 1);

      // PDF가 있으면 업로드 → 서버에서 Claude로 파싱
      var pdfParsedQuestions = <Map<String, dynamic>>[];
      if (surveyProvider.pdfPath != null) {
        try {
          final uploadResult = await apiService.uploadFile(
            surveyProvider.pdfPath!,
            surveyProvider.pdfName ?? 'survey.pdf',
          );

          // 우선순위 1: 서버에서 Claude가 파싱한 결과
          debugPrint('업로드 결과 키: ${uploadResult.keys.toList()}');
          debugPrint('parsed_questions 타입: ${uploadResult['parsed_questions']?.runtimeType}');
          final serverParsed = uploadResult['parsed_questions'] as List<dynamic>?;
          debugPrint('serverParsed: ${serverParsed?.length ?? "null"}개');
          if (serverParsed != null && serverParsed.isNotEmpty) {
            pdfParsedQuestions = serverParsed
                .map((q) => {
                      'id': q['id'] ?? '',
                      'text': q['text'] ?? '',
                      'choices': List<String>.from(q['choices'] ?? []),
                    })
                .toList();
            surveyProvider.setStatusMessage('AI가 ${pdfParsedQuestions.length}개 질문 파싱 완료');
          } else {
            // 우선순위 2: 로컬 정규식 파싱 (폴백)
            final extractedText = uploadResult['extracted_text'] as String? ?? '';
            if (extractedText.isNotEmpty) {
              pdfParsedQuestions = _parseSurveyText(extractedText);
              surveyProvider.setStatusMessage('PDF에서 ${pdfParsedQuestions.length}개 질문 추출');
            }
          }
        } catch (e) {
          debugPrint('PDF 업로드/파싱 실패: $e');
        }
      }

      // Step 2: 설문 구조화
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _currentStep = 2);

      // 질문 데이터 준비 (PDF 파싱 결과 우선, 그 다음 flattenedQuestions, 마지막으로 기본 질문)
      final questions = surveyProvider.flattenedQuestions
          .map((q) => {
                'id': q.id,
                'text': q.question,
                'choices': q.options,
              })
          .toList();

      final questionsToSend = pdfParsedQuestions.isNotEmpty
          ? pdfParsedQuestions
          : questions.isNotEmpty
              ? questions
              : [
                  {
                    'id': 'q1',
                    'text': '이 제품/서비스에 대해 어떻게 생각하시나요?',
                    'choices': ['매우 좋음', '좋음', '보통', '나쁨', '매우 나쁨'],
                  }
                ];

      // Step 3: 시뮬레이션 생성
      setState(() => _currentStep = 3);
      final personaProvider = context.read<PersonaProvider>();
      final session = await apiService.createSimulation(
        panelCount: personaProvider.personas.length > 0
            ? personaProvider.personas.length
            : 10,
        questions: questionsToSend,
      );

      final sessionId = session['id'] as String?;
      if (sessionId == null || sessionId.isEmpty) {
        throw ApiException('세션 ID를 받지 못했습니다', session.toString());
      }
      surveyProvider.setActiveSession(sessionId);

      if (mounted) setState(() => _currentStep = 4);
      await _pollSession(surveyProvider, apiService, sessionId);
    } catch (e) {
      // API 실패 시 기존 더미 시뮬레이션으로 폴백
      if (!mounted) return;
      surveyProvider.setError('API 연결 실패: $e');

      for (int i = _currentStep; i < _steps.length; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          setState(() => _currentStep = i + 1);
        }
      }

      if (mounted) {
        setState(() => _isRunning = false);
        Navigator.pushReplacementNamed(context, '/result');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final personaProvider = context.watch<PersonaProvider>();
    final progress = _currentStep / _steps.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설문 진행'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showExitConfirmation(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 진행률 원형 표시
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  Center(
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // 현재 단계 표시
            Text(
              _currentStep < _steps.length
                  ? _steps[_currentStep]
                  : '완료!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),

            // 단계별 체크리스트
            ...List.generate(_steps.length, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : isCurrent
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                      color: isCompleted
                          ? Colors.green
                          : isCurrent
                              ? Colors.blue
                              : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _steps[index].replaceAll('...', ''),
                      style: TextStyle(
                        fontSize: 16,
                        color: isCompleted || isCurrent
                            ? Colors.black
                            : Colors.grey,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 40),

            // 페르소나 수 표시
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem('전체 페르소나', '${personaProvider.personas.length}명'),
                  _buildInfoItem('Junior', '${personaProvider.juniorPersonas.length}명'),
                  _buildInfoItem('Senior', '${personaProvider.seniorPersonas.length}명'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pollSession(SurveyProvider surveyProvider, ApiService apiService, String sessionId) async {
    String status = 'pending';
    int errorCount = 0;
    const maxErrors = 10; // 연속 10번 실패하면 중단
    int polls = 0;
    const maxPolls = 200; // 3초 * 200 ≈ 10분 절대 상한 (무한 폴링 방지)

    while (status != 'completed' && status != 'failed') {
      if (_disposed) return; // 화면이 사라지면 폴링 종료
      if (polls++ >= maxPolls) {
        status = 'failed';
        surveyProvider.setError('시뮬레이션 시간 초과 (10분)');
        break;
      }
      await Future.delayed(const Duration(seconds: 3));
      if (_disposed) return;

      try {
        final statusData = await apiService.getSimulationStatus(sessionId);
        status = statusData['status'] as String? ?? 'pending';
        final progress = (statusData['progress'] as num?)?.toDouble() ?? 0.0;
        errorCount = 0; // 성공하면 에러 카운트 리셋

        surveyProvider.setProgress(progress);
        if (mounted) {
          if (status == 'running_survey') {
            setState(() => _currentStep = 4);
          } else if (status == 'calibrating') {
            setState(() => _currentStep = 5);
          }
        }
      } catch (e) {
        errorCount++;
        debugPrint('폴링 실패 ($errorCount/$maxErrors): $e');
        if (errorCount >= maxErrors) {
          status = 'failed';
          surveyProvider.setError('서버 연결 실패 (${maxErrors}회 재시도 후 중단)');
          break;
        }
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    debugPrint('시뮬레이션 최종 상태: $status');

    if (status == 'completed') {
      try {
        final result = await apiService.getSimulationResult(sessionId);
        if (_disposed) return;
        surveyProvider.setSimulationResult(result);
        surveyProvider.setStatusMessage('시뮬레이션 완료');
        surveyProvider.setActiveSession(null);

        // 알림 (화면이 dispose 됐으면 context 접근 금지)
        if (!mounted) return;
        final personaProvider = context.read<PersonaProvider>();
        await NotificationService.showSimulationComplete(
          panelCount: personaProvider.personas.length,
          questionCount: surveyProvider.flattenedQuestions.length,
        );

        // 히스토리 저장
        if (mounted) {
          final userProvider = context.read<UserProvider>();
          final history = SurveyHistory(
            id: sessionId,
            title: surveyProvider.flattenedQuestions.isNotEmpty
                ? surveyProvider.flattenedQuestions.first.question
                : '설문 시뮬레이션',
            createdAt: DateTime.now(),
            personaCount: personaProvider.personas.length,
            accuracy: (result['accuracy'] as num?)?.toDouble() ?? 0.0,
            status: 'completed',
          );
          await userProvider.addToHistory(history);
        }
      } catch (e) {
        debugPrint('결과 조회 실패: $e');
        surveyProvider.setError('결과 조회 실패: $e');
      }
    } else {
      surveyProvider.setError('시뮬레이션이 실패했습니다.');
      surveyProvider.setActiveSession(null);
    }

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isRunning = false);
      if (surveyProvider.simulationResult != null) {
        Navigator.pushReplacementNamed(context, '/result');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('시뮬레이션 실패: ${surveyProvider.error ?? "알 수 없는 오류"}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설문 진행 중단'),
        content: const Text('설문을 중단하시겠습니까?\n진행 중인 데이터가 손실될 수 있습니다.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('계속하기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
              Navigator.pop(context); // 설문 화면 나가기
            },
            child: const Text(
              '나가기',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// PDF에서 추출한 텍스트를 설문 질문으로 파싱
  /// 질문 패턴: "?" 끝, 번호 시작 (1. 2. Q1 등), 테이블 행
  /// 보기 패턴: ①②③, 1) 2) 3), 가. 나. 다., □ ○ 등
  List<Map<String, dynamic>> _parseSurveyText(String text) {
    final questions = <Map<String, dynamic>>[];
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    int qIdx = 0;
    String? currentQuestion;
    List<String> currentChoices = [];

    // 질문 패턴: "?" 끝, 숫자+점 시작, Q+숫자 시작
    final questionPattern = RegExp(
      r'^(\d+[\.\)]\s*|Q\d+[\.\):\s]|문\d+[\.\):\s]|【.+】)',
      caseSensitive: false,
    );
    // 보기 패턴: ①②③, ）①, 1) 2), 가. 나., □, ○, ●
    final choicePattern = RegExp(
      r'^(\s*[)）]\s*[①②③④⑤⑥⑦⑧⑨⑩]|[①②③④⑤⑥⑦⑧⑨⑩]|\d+\)\s*|[)）]\s*\d+|[가나다라마바사]\.\s*|[□○●■]\s*|[-·]\s*)',
    );
    // 테이블 구분자
    final tableRowPattern = RegExp(r'\|');

    // 안내문/인사말 필터 (질문이 아닌 텍스트)
    final skipPattern = RegExp(
      r'(안녕하십니까|안녕하세요|감사합니다|바랍니다|주십시오|약속합니다|것입니다|부록|설문|조사된|계획을|자료로)',
    );

    for (final line in lines) {
      final trimmed = line.trim();

      // 페이지 헤더/안내문 무시
      if (trimmed.startsWith('[페이지') || trimmed.startsWith('[표')) continue;
      if (trimmed.length > 40 && skipPattern.hasMatch(trimmed) && !questionPattern.hasMatch(trimmed)) continue;

      // 질문 감지: 번호 패턴으로 시작 (1. 2. Q1 문1 등)
      // "?"로만 끝나는 건 번호 없으면 질문 아님 (안내문 방지)
      final hasNumber = questionPattern.hasMatch(trimmed);
      final isQuestion = hasNumber ||
          (trimmed.endsWith('?') && trimmed.length < 80 && !skipPattern.hasMatch(trimmed));

      // 보기 감지
      final isChoice = choicePattern.hasMatch(trimmed);

      // 테이블 행 감지 (설문 표)
      final isTableRow = tableRowPattern.allMatches(trimmed).length >= 2;

      if (isQuestion && !isChoice) {
        // 이전 질문 저장
        if (currentQuestion != null) {
          qIdx++;
          questions.add({
            'id': 'q$qIdx',
            'text': currentQuestion,
            'choices': List<String>.from(currentChoices),
          });
        }
        // 번호 제거 후 질문 텍스트만
        currentQuestion = trimmed
            .replaceFirst(questionPattern, '')
            .trim();
        if (currentQuestion!.isEmpty) currentQuestion = trimmed;
        currentChoices = [];
      } else if (isChoice && currentQuestion != null) {
        // 보기 번호 제거 후 텍스트만
        final choiceText = trimmed
            .replaceFirst(choicePattern, '')
            .trim();
        if (choiceText.isNotEmpty) {
          currentChoices.add(choiceText);
        }
      } else if (isTableRow && currentQuestion != null) {
        // 테이블 행의 셀을 보기로 추가
        final cells = trimmed.split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        for (final cell in cells) {
          if (cell.length > 1 && !currentChoices.contains(cell)) {
            currentChoices.add(cell);
          }
        }
      }
    }

    // 마지막 질문 저장
    if (currentQuestion != null) {
      qIdx++;
      questions.add({
        'id': 'q$qIdx',
        'text': currentQuestion,
        'choices': List<String>.from(currentChoices),
      });
    }

    // 질문이 하나도 안 나왔으면 전체 텍스트를 개방형 질문으로
    if (questions.isEmpty) {
      questions.add({
        'id': 'q1',
        'text': text.length > 500 ? text.substring(0, 500) : text,
        'choices': <String>[],
      });
    }

    return questions;
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
