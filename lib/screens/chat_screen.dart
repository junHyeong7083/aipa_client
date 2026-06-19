import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late AnimationController _dotAnimController;

  // 대기 중인 첨부 파일 (전송 전 미리보기)
  String? _pendingAttachmentPath;
  String? _pendingAttachmentName;
  String? _pendingAttachmentType;

  // prompt_screen에서 전달받는 인자들
  String? _goal;
  String? _format;
  String? _fileName;
  String? _filePath;
  String? _fileType;
  String? _extractedText;
  Map<String, dynamic> _persona = {};
  String _personaName = 'AI 교수님';
  String? _platform; // 선택한 커뮤니티 말투 (youtube/dcinside/naver 등)
  // 멀티 커뮤니티에서 들어온 경우: 대화 히스토리 이어받기 + 변경 콜백
  void Function(List<Map<String, String>>)? _onUpdate;
  // 유저별 영구 저장용
  String? _userId;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _dotAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _dotAnimController.dispose();
    super.dispose();
  }

  void _initializeChat() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final prompt = args?['prompt'] ?? '질문이 없습니다';
    _goal = args?['goal'] as String?;
    _format = args?['format'] as String?;
    _fileName = args?['fileName'] as String?;
    _filePath = args?['filePath'] as String?;
    _fileType = args?['fileType'] as String?;
    _platform = args?['platform'] as String?;
    _onUpdate = args?['onUpdate'] as void Function(List<Map<String, String>>)?;
    final history = args?['history'] as List?;

    // 유저별 영구 저장: userId + 세션 id 준비
    _userId = context.read<UserProvider>().currentUser?.uid;

    // persona 정보가 전달되면 사용, 아니면 기본 페르소나
    if (args?['persona'] != null) {
      _persona = args!['persona'] as Map<String, dynamic>;
      _personaName = _persona['name'] ?? 'AI 교수님';
    } else {
      _persona = {
        'name': 'AI 교수님',
        'gender': '남성',
        'age': 45,
        'occupation': '대학교수',
        'description': '다양한 분야의 전문 지식을 갖춘 AI 교수님',
        'socialStatus': 'senior',
      };
      _personaName = 'AI 교수님';
    }

    // 세션 id:
    //  - 재진입(이전 대화에서 들어옴)이면 전달된 sessionId 로 그 세션을 이어감
    //  - 새 대화면 매번 고유 id 생성 → 같은 커뮤니티라도 대화마다 별도 세션으로 분리
    final base = _platform != null ? 'plat_$_platform' : 'persona_$_personaName';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    _sessionId = (args?['sessionId'] as String?) ??
        (_userId != null ? '${_userId}__${base}__$stamp' : '${base}__$stamp');

    // 멀티 커뮤니티/기존 대화에서 넘어온 경우: 히스토리를 이어받아 복원 (재생성 X)
    if (history != null && history.isNotEmpty) {
      setState(() {
        if (_filePath != null) {
          _messages.add(ChatMessage(
            content: _fileName ?? '사진',
            isUser: true,
            timestamp: DateTime.now(),
            attachmentPath: _filePath,
            attachmentType: _fileType ?? 'image',
          ));
        }
        for (final item in history) {
          final m = Map<String, dynamic>.from(item as Map);
          final isUser = m['role'] == 'user';
          _messages.add(ChatMessage(
            content: (m['content'] ?? '').toString(),
            isUser: isUser,
            timestamp: DateTime.now(),
            personaName: isUser ? null : _personaName,
          ));
        }
      });
      _scrollToBottom();
      _persistChat(); // 멀티커뮤니티/재진입 대화도 즉시 저장 (목록에 뜨도록)
      return; // 사용자가 이어서 입력할 때까지 대기
    }

    // 파일이 있으면 먼저 업로드 시도 + 채팅 버블로 표시
    if (_filePath != null && _fileName != null) {
      setState(() {
        _messages.add(ChatMessage(
          content: _fileName!,
          isUser: true,
          timestamp: DateTime.now(),
          attachmentPath: _filePath,
          attachmentType: _fileType ?? 'document',
        ));
      });
      await _uploadFileToBackend();
    }

    // 사용자 질문 추가
    setState(() {
      _messages.add(ChatMessage(
        content: prompt,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    // AI 응답 요청
    await _requestAiResponse(prompt);
  }

  /// 파일을 백엔드에 업로드하고 추출된 텍스트를 저장
  Future<void> _uploadFileToBackend() async {
    try {
      final result = await ApiService().uploadFile(_filePath!, _fileName!);
      if (result['extracted_text'] != null) {
        _extractedText = result['extracted_text'] as String;
      }
    } catch (e) {
      debugPrint('파일 업로드 실패 (로컬 파일 경로로 대체): $e');
      // 업로드 실패해도 채팅은 계속 진행
    }
  }

  /// 메시지 히스토리를 API 전송용 포맷으로 변환
  /// 마지막 메시지는 제외 (현재 전송 중인 메시지와 중복 방지)
  List<Map<String, String>> _buildHistory() {
    final textMsgs = _messages.where((m) => m.attachmentPath == null).toList();
    if (textMsgs.length <= 1) return [];
    return textMsgs.sublist(0, textMsgs.length - 1).map((m) {
      return {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      };
    }).toList();
  }

  List<Map<String, String>> _textHistory() => _messages
      .where((m) => m.attachmentPath == null)
      .map((m) => {
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.content,
          })
      .toList();

  /// 현재 대화(텍스트)를 멀티 커뮤니티 화면으로 되돌려 그리드/히스토리 최신화
  void _emitUpdate() {
    if (_onUpdate == null) return;
    _onUpdate!(_textHistory());
  }

  /// 유저별 영구 저장 (답변 올 때마다 upsert).
  /// 제목 = 첫 사용자 메시지(주제) → 같은 커뮤니티의 여러 세션을 구분.
  void _persistChat() {
    if (_userId == null || _sessionId == null) return;
    final hist = _textHistory();
    String title = _personaName;
    for (final m in hist) {
      final c = (m['content'] ?? '').trim();
      if (m['role'] == 'user' && c.isNotEmpty) {
        title = c.length > 30 ? '${c.substring(0, 30)}…' : c;
        break;
      }
    }
    ApiService().saveChat(
      userId: _userId!,
      sessionId: _sessionId!,
      platform: _platform,
      title: title,
      messages: hist,
    );
  }

  /// AI 응답을 API로 요청하고, 실패 시 Mock 응답으로 fallback
  Future<void> _requestAiResponse(String message) async {
    try {
      final response = await ApiService().sendChatMessage(
        message: message,
        persona: _persona,
        platform: _platform,
        goal: _goal,
        format: _format,
        history: _buildHistory(),
        filePath: _filePath,
        fileName: _fileName,
        extractedText: _extractedText,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(
            content: response,
            isUser: false,
            timestamp: DateTime.now(),
            personaName: _personaName,
          ));
        });
        _scrollToBottom();
        _emitUpdate();
        _persistChat();
      }
    } catch (e) {
      debugPrint('API 호출 실패, Mock 응답 사용: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(
            content: _generateMockResponse(message),
            isUser: false,
            timestamp: DateTime.now(),
            personaName: '$_personaName (오프라인)',
          ));
        });
        _scrollToBottom();
        _emitUpdate();
        _persistChat();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('서버 연결 실패. 임시 응답을 표시합니다.'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _generateMockResponse(String prompt) {
    return '''안녕하세요! 질문해 주셔서 감사합니다.

**요약:**
전반적으로 좋은 접근 방식을 가지고 계시지만, 몇 가지 개선점이 있습니다.

**피드백:**
1. 논리 구조가 명확하고 흐름이 자연스럽습니다.
2. 근거 자료를 좀 더 보완하면 설득력이 높아질 것 같습니다.
3. 결론 부분에서 핵심 메시지를 한 번 더 강조하면 좋겠습니다.

**개선 제안:**
- 서론에 배경 설명을 추가해 보세요
- 데이터나 통계를 인용하면 더 객관적으로 보일 수 있습니다

더 궁금한 점이 있으시면 말씀해 주세요!''';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade800),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.indigo.shade100,
              child: Icon(Icons.school, size: 18, color: Colors.indigo.shade600),
            ),
            const SizedBox(width: 8),
            Text(
              _personaName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
            onPressed: () => _showOptionsMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 메시지 리스트
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'AI 패널에게 질문해 보세요',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '아래 입력창에 메시지를 입력하면\n대화가 시작됩니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return _buildLoadingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // 첨부 파일 미리보기
          if (_pendingAttachmentPath != null) _buildPendingAttachment(),

          // 입력 영역
          _buildInputArea(),
        ],
      ),
    );
  }

  /// 첨부 파일 미리보기 (전송 전)
  Widget _buildPendingAttachment() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          // 이미지면 썸네일
          if (_pendingAttachmentType == 'image')
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(_pendingAttachmentPath!),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.image, size: 32, color: Colors.blue.shade600),
              ),
            )
          else
            Icon(Icons.description, size: 32, color: Colors.blue.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pendingAttachmentName ?? '',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '메시지와 함께 전송됩니다',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade500),
                ),
              ],
            ),
          ),
          // 취소 버튼
          GestureDetector(
            onTap: () {
              setState(() {
                _pendingAttachmentPath = null;
                _pendingAttachmentName = null;
                _pendingAttachmentType = null;
              });
            },
            child: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.indigo.shade100,
              child: Icon(Icons.school, size: 16, color: Colors.indigo.shade600),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue.shade600 : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser && message.personaName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.personaName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo.shade600,
                        ),
                      ),
                    ),
                  // 첨부 파일이면 이미지/아이콘 표시
                  if (message.attachmentPath != null) ...[
                    if (message.attachmentType == 'image')
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(message.attachmentPath!),
                          width: 200,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 200,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, color: Colors.blue.shade600, size: 20),
                                const SizedBox(width: 8),
                                Text(message.content, style: TextStyle(fontSize: 13, color: Colors.blue.shade800)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blue.shade400 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description, size: 20, color: isUser ? Colors.white : Colors.blue.shade600),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                message.content,
                                style: TextStyle(fontSize: 13, color: isUser ? Colors.white : Colors.blue.shade800),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '파일 첨부됨',
                      style: TextStyle(fontSize: 11, color: isUser ? Colors.white70 : Colors.grey.shade500),
                    ),
                  ] else
                    Text(
                      message.content,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 15,
                        color: isUser ? Colors.white : Colors.grey.shade800,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              child: Icon(Icons.person, size: 16, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.indigo.shade100,
            child: Icon(Icons.school, size: 16, color: Colors.indigo.shade600),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _dotAnimController,
      builder: (context, child) {
        final delay = index * 0.2;
        final t = ((_dotAnimController.value - delay) % 1.0).clamp(0.0, 1.0);
        final bounce = (t < 0.5) ? (t * 2) : (2 - t * 2);
        return Transform.translate(
          offset: Offset(0, -6 * bounce),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade400.withValues(alpha: 0.5 + 0.5 * bounce),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add, color: Colors.grey.shade600),
              onPressed: _showAttachMenu,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue.shade600,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    final hasPending = _pendingAttachmentPath != null;

    // 텍스트도 없고 첨부도 없으면 무시
    if (text.isEmpty && !hasPending) return;
    if (_isLoading) return;

    // 첨부 파일이 있으면 먼저 채팅 버블에 표시
    if (hasPending) {
      setState(() {
        _messages.add(ChatMessage(
          content: _pendingAttachmentName ?? '파일',
          isUser: true,
          timestamp: DateTime.now(),
          attachmentPath: _pendingAttachmentPath,
          attachmentType: _pendingAttachmentType,
        ));
      });

      // 파일 업로드 + 컨텍스트 갱신
      _fileName = _pendingAttachmentName;
      _filePath = _pendingAttachmentPath;
      _fileType = _pendingAttachmentType;
      _extractedText = null;
      await _uploadFileToBackend();

      // pending 초기화
      _pendingAttachmentPath = null;
      _pendingAttachmentName = null;
      _pendingAttachmentType = null;
    }

    // 텍스트 메시지 추가
    final messageText = text.isNotEmpty ? text : '이 파일에 대해 분석해주세요.';
    setState(() {
      if (text.isNotEmpty) {
        _messages.add(ChatMessage(
          content: text,
          isUser: true,
          timestamp: DateTime.now(),
        ));
      }
      _messageController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    // AI 응답 요청
    await _requestAiResponse(messageText);
  }

  void _showOptionsMenu() {
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
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('결과 저장'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/result');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('공유하기'),
                onTap: () {
                  Navigator.pop(context);
                  _copyConversationToClipboard();
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('새로운 페르소나로 재생성'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/main');
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('자극물 변경'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/upload');
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showAttachMenu() {
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
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.purple.shade600),
                title: const Text('카메라로 촬영'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFromCamera();
                },
              ),
              ListTile(
                leading: Icon(Icons.image, color: Colors.green.shade600),
                title: const Text('이미지 첨부 (갤러리)'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadFile('image');
                },
              ),
              ListTile(
                leading: Icon(Icons.description, color: Colors.blue.shade600),
                title: const Text('문서 첨부 (PDF/CSV)'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadFile('document');
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// 카메라로 사진 촬영 → 첨부 미리보기에 등록
  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (shot == null) return; // 사용자가 취소

      setState(() {
        _pendingAttachmentPath = shot.path;
        _pendingAttachmentName = shot.name.isNotEmpty ? shot.name : 'camera.jpg';
        _pendingAttachmentType = 'image';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카메라 사용 실패: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadFile(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type == 'image' ? FileType.image : FileType.custom,
        allowedExtensions: type == 'image' ? null : ['pdf', 'csv', 'doc', 'docx'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      // 미리보기 상태로만 저장 (전송은 유저가 보내기 버튼 누를 때)
      setState(() {
        _pendingAttachmentPath = file.path;
        _pendingAttachmentName = file.name;
        _pendingAttachmentType = type;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('파일 첨부 실패: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  void _copyConversationToClipboard() {
    final buffer = StringBuffer();
    for (final message in _messages) {
      final sender = message.isUser ? '나' : (message.personaName ?? _personaName);
      buffer.writeln('[$sender]');
      buffer.writeln(message.content);
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대화 내용이 클립보드에 복사되었습니다')),
      );
    }
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? personaName;
  final String? attachmentPath;
  final String? attachmentType;

  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.personaName,
    this.attachmentPath,
    this.attachmentType,
  });
}
