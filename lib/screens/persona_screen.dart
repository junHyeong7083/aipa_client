import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/selection_provider.dart';
import '../providers/persona_provider.dart';
import '../providers/survey_provider.dart';
import '../widgets/persona_card.dart';

class PersonaScreen extends StatefulWidget {
  const PersonaScreen({super.key});

  @override
  State<PersonaScreen> createState() => _PersonaScreenState();
}

class _PersonaScreenState extends State<PersonaScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 페르소나 생성
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generatePersonas();
    });
  }

  void _generatePersonas({bool force = false}) {
    final personaProvider = context.read<PersonaProvider>();

    // 이미 페르소나가 있으면 재생성하지 않음 (CustomPersonaScreen에서 생성된 경우)
    if (!force && personaProvider.personas.isNotEmpty) return;

    final selectionProvider = context.read<SelectionProvider>();
    personaProvider.generatePersonas(selectionProvider.selection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('페르소나 목록'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _generatePersonas(force: true),
            tooltip: '새로고침',
          ),
        ],
      ),
      bottomNavigationBar: Consumer<PersonaProvider>(
        builder: (context, provider, _) {
          if (provider.personas.isEmpty) return const SizedBox();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _startSurvey(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0064FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('설문 시작', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          );
        },
      ),
      body: Consumer<PersonaProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('페르소나 생성 중...'),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _generatePersonas(force: true),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          if (provider.personas.isEmpty) {
            return const Center(
              child: Text('생성된 페르소나가 없습니다.'),
            );
          }

          return Column(
            children: [
              // 요약 정보
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      '전체',
                      provider.personas.length.toString(),
                      Colors.blue,
                    ),
                    _buildStatItem(
                      '주니어 (10~30대)',
                      provider.juniorPersonas.length.toString(),
                      Colors.green,
                    ),
                    _buildStatItem(
                      '시니어 (40대+)',
                      provider.seniorPersonas.length.toString(),
                      Colors.orange,
                    ),
                  ],
                ),
              ),

              // 페르소나 리스트
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: provider.personas.length,
                  itemBuilder: (context, index) {
                    final persona = provider.personas[index];
                    return PersonaCard(
                      persona: persona,
                      onTap: () => _showPersonaDetail(persona),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
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

  void _showPersonaDetail(persona) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    persona.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('성별', persona.gender),
                  _buildDetailRow('나이', '${persona.age}세'),
                  _buildDetailRow('직업', persona.occupation),
                  _buildDetailRow(
                    '사회적 위치',
                    persona.socialStatus == 'junior' ? '주니어' : '시니어',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '설명',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    persona.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.fade,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _startSurvey() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '설문지 업로드',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PDF 형식의 설문지를 업로드해주세요',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // PDF 업로드 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _pickPdfFile(),
                  icon: const Icon(Icons.upload_file),
                  label: const Text(
                    'PDF 파일 선택',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 더미 설문으로 테스트
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/survey');
                  },
                  icon: const Icon(Icons.science),
                  label: const Text(
                    '더미 설문으로 테스트',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        final file = result.files.first;
        final fileName = file.name;
        final filePath = file.path;

        if (mounted) {
          // 파일 정보를 SurveyProvider에 저장
          context.read<SurveyProvider>().setPdfFile(filePath, fileName);

          Navigator.pop(context); // 바텀시트 닫기

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('선택된 파일: $fileName')),
          );

          // 설문 화면으로 이동
          Navigator.pushNamed(context, '/survey');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 선택 오류: $e')),
        );
      }
    }
  }
}
