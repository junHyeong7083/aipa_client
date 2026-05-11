import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/survey_provider.dart';
import '../providers/persona_provider.dart';

class SurveyResultScreen extends StatelessWidget {
  const SurveyResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final surveyProvider = context.watch<SurveyProvider>();
    final personaProvider = context.watch<PersonaProvider>();
    final result = surveyProvider.simulationResult;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade800),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '시뮬레이션 결과',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.grey.shade700),
            onPressed: () => _exportCsv(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 요약 카드
              _buildSummaryCard(context, personaProvider, result),
              const SizedBox(height: 20),

              // 질문별 응답 분포 차트 (동적 생성)
              if (result != null) ..._buildDistributionCharts(result),

              // 결과 없으면 안내
              if (result == null)
                _buildNoResultCard(),

              const SizedBox(height: 20),

              // 개별 응답 상세
              if (result != null) _buildDetailedResponses(result),

              const SizedBox(height: 20),

              // 액션 버튼
              _buildActionButtons(context, surveyProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, PersonaProvider personaProvider, Map<String, dynamic>? result) {
    final panelCount = personaProvider.personas.length;
    final fidelity = result?['distribution_fidelity'] as num?;
    final consistency = result?['consistency_score'] as num?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'AI 패널 $panelCount명',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              const Spacer(),
              if (fidelity != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '충실도 ${(fidelity * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '설문 시뮬레이션 결과',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            result != null
                ? '$panelCount명의 AI 패널이 분석을 완료했습니다'
                : '결과를 불러오는 중...',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDistributionCharts(Map<String, dynamic> result) {
    final distribution = result['response_distribution'] as Map<String, dynamic>?;
    if (distribution == null || distribution.isEmpty) return [];

    // 질문 ID → 텍스트 매핑 (서버에서 제공)
    final questionTexts = result['question_texts'] as Map<String, dynamic>? ?? {};

    final widgets = <Widget>[];

    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          '질문별 응답 분포',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
        ),
      ),
    );

    int qIndex = 0;
    for (final entry in distribution.entries) {
      qIndex++;
      final questionId = entry.key;
      final questionText = questionTexts[questionId] as String? ?? questionId;
      final choices = entry.value as Map<String, dynamic>;

      widgets.add(_buildQuestionChart(qIndex, questionText, choices));
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  Widget _buildQuestionChart(int index, String questionId, Map<String, dynamic> choices) {
    // 비율 정렬 (높은 순)
    final sorted = choices.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    final colors = [
      const Color(0xFF4A90D9),
      const Color(0xFF5BA8A0),
      const Color(0xFFF5A623),
      const Color(0xFFD0021B),
      const Color(0xFF9B59B6),
      const Color(0xFF2ECC71),
      const Color(0xFFE67E22),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 질문 제목
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Q$index',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  questionId,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 각 선택지별 바 차트
          ...sorted.asMap().entries.map((e) {
            final idx = e.key;
            final choice = e.value.key;
            final ratio = (e.value.value as num).toDouble();
            final percent = (ratio * 100).toInt();
            final color = colors[idx % colors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          choice,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailedResponses(Map<String, dynamic> result) {
    final responses = result['detailed_responses'] as List<dynamic>? ?? [];
    if (responses.isEmpty) return const SizedBox();

    // 최대 5개만 표시
    final displayResponses = responses.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '개별 응답 샘플',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 12),
        ...displayResponses.map((r) {
          final resp = r as Map<String, dynamic>;
          final choice = resp['selected_choice'] ?? resp['scale_value']?.toString() ?? '';
          final explanation = resp['explanation'] ?? '';
          final personaId = resp['persona_id'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.blue.shade400),
                    const SizedBox(width: 6),
                    Text(
                      personaId.toString().substring(0, personaId.toString().length.clamp(0, 8)),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        choice.toString(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
                if (explanation.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    explanation.toString(),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNoResultCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            '시뮬레이션 결과가 없습니다',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '설문을 먼저 실행해주세요',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SurveyProvider surveyProvider) {
    return Column(
      children: [
        // CSV 저장
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _exportCsv(context),
            icon: const Icon(Icons.table_chart, size: 20),
            label: const Text('CSV 저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 홈으로
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('홈으로 돌아가기', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
          ),
        ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final provider = context.read<SurveyProvider>();
    final result = provider.simulationResult;
    if (result == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내보낼 결과가 없습니다')),
        );
      }
      return;
    }

    try {
      final distribution = result['response_distribution'] as Map<String, dynamic>? ?? {};
      final detailedResponses = result['detailed_responses'] as List<dynamic>? ?? [];

      // Build CSV rows from simulation result
      final questionIds = distribution.keys.toList();
      final header = ['persona_id', ...questionIds];
      final dataRows = <List<String>>[];

      for (final resp in detailedResponses) {
        final r = resp as Map<String, dynamic>;
        final personaId = r['persona_id']?.toString() ?? '';
        final row = <String>[personaId];
        for (final qId in questionIds) {
          final choice = r['selected_choice']?.toString() ?? r['scale_value']?.toString() ?? '';
          row.add(choice);
        }
        dataRows.add(row);
      }

      final csvData = const ListToCsvConverter().convert([header, ...dataRows]);

      // Save to documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/survey_results_$timestamp.csv');
      await file.writeAsString('\uFEFF$csvData');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 저장 완료: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 저장 실패: $e')),
        );
      }
    }
  }
}
