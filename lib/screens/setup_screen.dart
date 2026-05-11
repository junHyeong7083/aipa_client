import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/selection_provider.dart';
import '../providers/survey_provider.dart';
import '../widgets/ratio_slider.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? _selectedPdfName;
  String? _selectedPdfPath;

  // 드롭다운 옵션들
  final List<String> methodOptions = [
    '심리학',
    '사회학',
    '경영학',
    '마케팅',
    '교육학',
    'IT/기술',
    '의료/보건',
    '기타',
  ];

  final List<int> sampleSizeOptions = [10, 20, 30, 50, 100];

  final List<String> screeningRuleOptions = [
    '전체',
    '20대 이상',
    '직장인만',
    '특정 지역',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설문 설정'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Consumer<SelectionProvider>(
        builder: (context, provider, child) {
          final selection = provider.selection;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타이틀
                const Text(
                  '새 설문 시뮬레이션',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI 페르소나가 설문에 응답합니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Step 1: PDF 업로드
                _buildStepHeader('1', 'PDF 설문지 업로드'),
                const SizedBox(height: 12),
                _buildPdfUploadSection(),
                const SizedBox(height: 32),

                // Step 2: 페르소나 설정
                _buildStepHeader('2', '페르소나 설정'),
                const SizedBox(height: 16),

                // 연구 방법/분야
                _buildSectionTitle('연구 분야'),
                const SizedBox(height: 8),
                _buildDropdown(
                  value: selection.method.isEmpty ? null : selection.method,
                  hint: '분야를 선택하세요',
                  items: methodOptions,
                  onChanged: (v) => provider.setMethod(v!),
                ),
                const SizedBox(height: 20),

                // 샘플 수
                _buildSectionTitle('페르소나 수'),
                const SizedBox(height: 8),
                _buildDropdown(
                  value: selection.sampleSize,
                  hint: '샘플 수 선택',
                  items: sampleSizeOptions,
                  onChanged: (v) => provider.setSampleSize(v!),
                ),
                const SizedBox(height: 20),

                // 스크리닝 규칙
                _buildSectionTitle('스크리닝 규칙'),
                const SizedBox(height: 8),
                _buildDropdown(
                  value: selection.screeningRule.isEmpty
                      ? null
                      : selection.screeningRule,
                  hint: '규칙을 선택하세요',
                  items: screeningRuleOptions,
                  onChanged: (v) => provider.setScreeningRule(v!),
                ),
                const SizedBox(height: 24),

                // 성별 비율
                GenderRatioSlider(
                  maleRatio: selection.maleRatio,
                  onChanged: provider.setGenderRatio,
                ),
                const SizedBox(height: 24),

                // 연령대별 비율
                _buildSectionTitle('연령대별 비율'),
                const SizedBox(height: 16),
                ...selection.ageRatios.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RatioSlider(
                      label: _getAgeLabel(entry.key),
                      value: entry.value,
                      onChanged: (v) => provider.setAgeRatio(entry.key, v),
                    ),
                  );
                }),
                const SizedBox(height: 32),

                // 시작 버튼
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canStart(provider)
                        ? () => _startSurvey()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '설문 시뮬레이션 시작',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 테스트 버튼 (PDF 없이)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: provider.isValid()
                        ? () => _startTestSurvey()
                        : null,
                    icon: const Icon(Icons.science),
                    label: const Text('더미 설문으로 테스트'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildStepHeader(String number, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPdfUploadSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedPdfName != null ? Colors.green : Colors.grey.shade300,
          width: _selectedPdfName != null ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          if (_selectedPdfName == null) ...[
            Icon(Icons.upload_file, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'PDF 설문지를 업로드하세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickPdfFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('파일 선택'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPdfName!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '업로드 완료',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedPdfName = null;
                      _selectedPdfPath = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickPdfFile,
                icon: const Icon(Icons.refresh),
                label: const Text('다른 파일 선택'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString()),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _getAgeLabel(String key) {
    switch (key) {
      case '10s':
        return '10대';
      case '20s':
        return '20대';
      case '30s':
        return '30대';
      case '40s':
        return '40대';
      case '50s+':
        return '50대 이상';
      default:
        return key;
    }
  }

  bool _canStart(SelectionProvider provider) {
    return _selectedPdfName != null && provider.isValid();
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        final file = result.files.first;
        setState(() {
          _selectedPdfName = file.name;
          _selectedPdfPath = file.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 선택 오류: $e')),
        );
      }
    }
  }

  void _startSurvey() {
    // PDF 파일 경로를 SurveyProvider에 저장
    context.read<SurveyProvider>().setPdfFile(_selectedPdfPath, _selectedPdfName);
    Navigator.pushNamed(context, '/persona');
  }

  void _startTestSurvey() {
    Navigator.pushNamed(context, '/persona');
  }
}
