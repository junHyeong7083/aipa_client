import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';

/// 이전 대화 목록 (카톡 채팅방 리스트). 유저별 저장된 대화방을 보여주고 재진입.
class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  static const Map<String, List<Object>> _platMeta = {
    'dcinside': ['🎮', Color(0xFF5B6770), '디시인사이드'],
    'youtube': ['▶️', Color(0xFFFF0000), '유튜브'],
    'naver': ['🟢', Color(0xFF03C75A), '네이버'],
    'instagram': ['📸', Color(0xFFE1306C), '인스타그램'],
  };

  String _formatTime(dynamic iso) {
    if (iso is! String || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final uid = context.read<UserProvider>().currentUser?.uid;
    setState(() {
      _future = uid != null ? ApiService().listChats(uid) : Future.value([]);
    });
  }

  Future<void> _open(Map<String, dynamic> s) async {
    final uid = context.read<UserProvider>().currentUser?.uid;
    if (uid == null) return;
    final msgs = await ApiService().getChatMessages(uid, s['id'] as String);
    if (!mounted) return;
    final meta = _platMeta[s['platform']];
    final community = meta != null ? meta[2] as String : (s['title'] ?? '대화').toString();
    await Navigator.pushNamed(context, '/chat', arguments: {
      'persona': {'name': community},
      if (s['platform'] != null) 'platform': s['platform'],
      'sessionId': s['id'],
      'history': msgs,
    });
    _load(); // 돌아오면 목록 갱신
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('이전 대화',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snap.data ?? [];
          if (chats.isEmpty) return _buildEmpty();
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
            itemCount: chats.length,
            itemBuilder: (context, i) => _buildRow(chats[i]),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text('아직 대화가 없어요',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text('커뮤니티를 골라 대화를 시작하면\n여기에 대화방이 쌓입니다',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('대화하러 가기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF191919),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> s) {
    final platform = s['platform'] as String?;
    final meta = _platMeta[platform];
    final emoji = meta != null ? meta[0] as String : '💬';
    final color = meta != null ? meta[1] as Color : Colors.blueGrey;
    final community = meta != null ? meta[2] as String : '대화';
    final topic = (s['title'] ?? s['lastMessage'] ?? '').toString(); // 첫 메시지(주제)
    final time = _formatTime(s['updatedAt']);
    return GestureDetector(
      onTap: () => _open(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(community,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: color),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (time.isNotEmpty)
                        Text(time, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(topic.isEmpty ? '새 대화' : topic,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}
