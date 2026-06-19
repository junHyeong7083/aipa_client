import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

/// 멀티 커뮤니티 — 같은 질문/사진을 4개 커뮤니티에 동시에 던져 반응을 2x2로 비교
class MultiCommunityScreen extends StatefulWidget {
  const MultiCommunityScreen({super.key});

  @override
  State<MultiCommunityScreen> createState() => _MultiCommunityScreenState();
}

class _Community {
  final String id; // 서버 platform 값
  final String name;
  final String emoji;
  final Color color;
  final Map<String, dynamic> persona;
  const _Community(this.id, this.name, this.emoji, this.color, this.persona);
}

const List<_Community> _communities = [
  _Community('dcinside', '디시인사이드', '🎮', Color(0xFF5B6770), {
    'name': '디시인', 'gender': '남성', 'age': 27, 'occupation': '대학생/직장인',
    'description': '디시인사이드 헤비유저. 냉소적이고 솔직하며 은어를 자주 씀', 'socialStatus': 'junior'
  }),
  _Community('youtube', '유튜브', '▶️', Color(0xFFFF0000), {
    'name': '유튜브 시청자', 'gender': '남성', 'age': 30, 'occupation': '콘텐츠 소비자',
    'description': '알고리즘 따라 다양한 영상 시청, 댓글 활발', 'socialStatus': 'junior'
  }),
  _Community('naver', '네이버', '🟢', Color(0xFF03C75A), {
    'name': '네이버 카페회원', 'gender': '여성', 'age': 38, 'occupation': '주부/직장인',
    'description': '정보 검색·후기 신뢰, 맘카페 활동', 'socialStatus': 'senior'
  }),
  _Community('instagram', '인스타그램', '📸', Color(0xFFE1306C), {
    'name': '인스타 유저', 'gender': '여성', 'age': 25, 'occupation': '트렌드 민감',
    'description': '비주얼 중심, 감성적 표현과 이모지를 자주 씀', 'socialStatus': 'junior'
  }),
];

class _Result {
  bool loading;
  String? text;
  String? error;
  _Result({this.loading = false, this.text, this.error});
}

class _MultiCommunityScreenState extends State<MultiCommunityScreen> {
  final _questionController = TextEditingController();
  String? _attachPath;
  String? _attachName;
  bool _running = false;

  final Map<String, _Result> _results = {
    for (final c in _communities) c.id: _Result(),
  };

  // 커뮤니티별 대화 히스토리 (1:1 채팅에서 이어가도 보존)
  final Map<String, List<Map<String, String>>> _conversations = {};

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  bool get _hasAnyResult =>
      _results.values.any((r) => r.loading || r.text != null || r.error != null);

  Future<void> _pickCamera() async {
    try {
      final shot = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2000);
      if (shot == null) return;
      setState(() {
        _attachPath = shot.path;
        _attachName = shot.name.isNotEmpty ? shot.name : 'camera.jpg';
      });
    } catch (e) {
      _toast('카메라 사용 실패: $e');
    }
  }

  Future<void> _pickGallery() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image);
      if (res == null || res.files.isEmpty || res.files.first.path == null) return;
      setState(() {
        _attachPath = res.files.first.path;
        _attachName = res.files.first.name;
      });
    } catch (e) {
      _toast('이미지 선택 실패: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600));
  }

  Future<void> _run() async {
    final q = _questionController.text.trim();
    if (q.isEmpty && _attachPath == null) {
      _toast('질문을 입력하거나 사진을 첨부하세요');
      return;
    }
    FocusScope.of(context).unfocus();
    final message = q.isNotEmpty ? q : '이 사진(제품)에 대해 어떻게 생각해?';

    setState(() {
      _running = true;
      for (final c in _communities) {
        _results[c.id] = _Result(loading: true);
      }
    });

    // 4개 커뮤니티에 병렬 요청 — 도착하는 대로 칸을 채움(차르륵 연출)
    await Future.wait(_communities.map((c) async {
      try {
        final resp = await ApiService().sendChatMessage(
          message: message,
          persona: c.persona,
          platform: c.id,
          format: 'short', // 그리드용 짧은 응답
          filePath: _attachPath,
          fileName: _attachName,
        );
        if (mounted) {
          setState(() {
            _results[c.id] = _Result(text: resp.trim());
            _conversations[c.id] = [
              {'role': 'user', 'content': message},
              {'role': 'assistant', 'content': resp.trim()},
            ];
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _results[c.id] = _Result(error: '응답 실패'));
        }
        debugPrint('multi[${c.id}] 실패: $e');
      }
    }));

    if (mounted) setState(() => _running = false);
  }

  /// 카드 탭 → 그 커뮤니티와 1:1 채팅으로 확대. 대화 히스토리를 이어받고,
  /// 새 답변이 생기면 콜백으로 그리드/히스토리를 최신화한다.
  void _openChat(_Community c) {
    final r = _results[c.id];
    if (r?.text == null) return;
    Navigator.pushNamed(context, '/chat', arguments: {
      'persona': {...c.persona, 'name': c.name},
      'platform': c.id,
      if (_attachPath != null) 'filePath': _attachPath,
      if (_attachName != null) 'fileName': _attachName,
      if (_attachPath != null) 'fileType': 'image',
      // 보관 중인 대화를 이어받음
      'history': List<Map<String, String>>.from(_conversations[c.id] ?? const []),
      // 새 메시지가 생길 때마다 멀티 화면으로 되돌려받기
      'onUpdate': (List<Map<String, String>> h) {
        if (!mounted) return;
        setState(() {
          _conversations[c.id] = h;
          final lastA = h.lastWhere(
            (m) => m['role'] == 'assistant',
            orElse: () => {'content': _results[c.id]?.text ?? ''},
          );
          _results[c.id] = _Result(text: lastA['content']);
        });
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('🆚 멀티 커뮤니티',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
      body: Column(
        children: [
          _buildInput(),
          Expanded(
            child: _hasAnyResult
                ? _buildGrid()
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('같은 질문, 커뮤니티별 다른 반응',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                          const SizedBox(height: 6),
                          Text('질문이나 사진을 넣고 “반응 생성”을 눌러보세요',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          if (_attachPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(File(_attachPath!), width: 40, height: 40, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_attachName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12))),
                GestureDetector(
                  onTap: () => setState(() {
                    _attachPath = null;
                    _attachName = null;
                  }),
                  child: const Icon(Icons.close, size: 18),
                ),
              ]),
            ),
          Row(children: [
            IconButton(
                icon: Icon(Icons.camera_alt, color: Colors.grey.shade600),
                onPressed: _running ? null : _pickCamera),
            IconButton(
                icon: Icon(Icons.image, color: Colors.grey.shade600),
                onPressed: _running ? null : _pickGallery),
            Expanded(
              child: TextField(
                controller: _questionController,
                decoration: InputDecoration(
                  hintText: '예: 이 신상 치킨 어때?',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _running ? null : _run(),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.bolt, size: 20),
              label: Text(_running ? '생성 중...' : '4개 커뮤니티 반응 생성',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF191919),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.count(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(context).viewPadding.bottom),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: _communities.map(_buildCell).toList(),
    );
  }

  Widget _buildCell(_Community c) {
    final r = _results[c.id]!;
    return GestureDetector(
      onTap: () => _openChat(c),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(top: BorderSide(color: c.color, width: 3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(c.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(c.name,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.color),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 10),
            Expanded(
              child: r.loading
                  ? const Center(
                      child: SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                  : r.error != null
                      ? Center(
                          child: Text(r.error!,
                              style: TextStyle(fontSize: 12, color: Colors.red.shade400)))
                      : Text(
                          r.text ?? '',
                          style: TextStyle(fontSize: 12.5, height: 1.45, color: Colors.grey.shade800),
                          maxLines: 8,
                          overflow: TextOverflow.fade,
                        ),
            ),
            if (r.text != null)
              Align(
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('1:1 대화 →',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.color)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
