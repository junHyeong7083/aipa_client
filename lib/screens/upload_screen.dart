import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/persona_provider.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _selectedFileType;
  String? _uploadedFileName;
  String? _uploadedFilePath;
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade800),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 안내 메시지 (모드에 따라 분기)
            Builder(builder: (context) {
              final routeArgs = ModalRoute.of(context)?.settings.arguments;
              final args = routeArgs is Map<String, dynamic> ? routeArgs : <String, dynamic>{};
              final mode = args['mode'] as String?;
              final persona = args['persona'] as Map<String, dynamic>?;
              final panelCount = context.watch<PersonaProvider>().personas.length;

              if (mode == 'chat' && persona != null) {
                // 채팅 모드: 선택한 페르소나 정보 표시
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble, color: Colors.purple.shade600, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        '${persona['name']}와(과)\n대화를 시작합니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade800, height: 1.4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${persona['occupation'] ?? ''} · ${persona['gender'] ?? ''}',
                        style: TextStyle(fontSize: 14, color: Colors.purple.shade400),
                      ),
                    ],
                  ),
                );
              }

              // 설문 모드: 패널 수 표시
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue.shade600, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      panelCount > 0
                          ? '$panelCount명의 AI 패널이\n생성되었습니다!'
                          : '파일을 첨부하고\n대화를 시작하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade800, height: 1.4),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),

            // 타이틀
            Text(
              '어떤 걸 보여줄까요?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 24),

            // 파일 타입 선택 버튼들
            _buildFileTypeButton(
              icon: Icons.image,
              label: '사진',
              description: 'JPG, PNG',
              type: 'image',
            ),
            const SizedBox(height: 12),
            _buildFileTypeButton(
              icon: Icons.description,
              label: '문서',
              description: 'PDF, CSV',
              type: 'document',
            ),
            const SizedBox(height: 12),
            _buildFileTypeButton(
              icon: Icons.chat_bubble_outline,
              label: '첨부파일 없이 대화로 시작',
              description: '바로 질문하기',
              type: 'chat',
            ),

            // 업로드된 파일 표시
            if (_uploadedFileName != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _uploadedFileName!,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.green.shade600),
                      onPressed: () {
                        setState(() {
                          _uploadedFileName = null;
                          _uploadedFilePath = null;
                          _selectedFileType = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],

            // 업로드 진행 표시
            if (_isUploading) ...[
              const SizedBox(height: 24),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                '파일 업로드 중...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],

            const SizedBox(height: 40),

            // 다음 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_uploadedFileName != null || _selectedFileType == 'chat')
                    ? () {
                        final routeArgs = ModalRoute.of(context)?.settings.arguments;
                        final inputArgs = routeArgs is Map<String, dynamic> ? routeArgs : <String, dynamic>{};
                        Navigator.pushNamed(context, '/prompt', arguments: {
                          'fileName': _uploadedFileName,
                          'filePath': _uploadedFilePath,
                          'fileType': _selectedFileType,
                          if (inputArgs.containsKey('persona')) 'persona': inputArgs['persona'],
                          if (inputArgs.containsKey('mode')) 'mode': inputArgs['mode'],
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '다음',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildFileTypeButton({
    required IconData icon,
    required String label,
    required String description,
    required String type,
  }) {
    final isSelected = _selectedFileType == type;

    return InkWell(
      onTap: () => _selectFileType(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.shade100
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.blue.shade700
                          : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.blue.shade600),
          ],
        ),
      ),
    );
  }

  Future<void> _selectFileType(String type) async {
    setState(() => _selectedFileType = type);

    if (type == 'chat') {
      // 대화로 시작하면 파일 업로드 필요 없음
      return;
    }

    // 파일 선택
    FileType fileType = FileType.any;
    List<String>? allowedExtensions;

    if (type == 'image') {
      fileType = FileType.image;
    } else if (type == 'document') {
      fileType = FileType.custom;
      allowedExtensions = ['pdf', 'csv'];
    }

    try {
      setState(() => _isUploading = true);

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _uploadedFileName = result.files.first.name;
          _uploadedFilePath = result.files.first.path;
        });
      } else {
        setState(() {
          _selectedFileType = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 선택 오류: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }
}
