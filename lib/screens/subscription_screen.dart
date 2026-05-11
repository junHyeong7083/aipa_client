import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/user_data.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionPlan? _selectedPlan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('구독 플랜'),
        centerTitle: true,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final currentPlan = userProvider.user?.plan ?? SubscriptionPlan.free;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 현재 플랜 정보
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '현재 구독 중인 플랜',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userProvider.user?.planDisplayName ?? 'Free',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  '플랜 선택',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Free 플랜
                _buildPlanCard(
                  plan: SubscriptionPlan.free,
                  title: 'Free',
                  price: '무료',
                  priceDetail: '',
                  features: [
                    '월 3회 설문 시뮬레이션',
                    '기본 페르소나 생성',
                    '결과 리포트 제공',
                  ],
                  color: Colors.grey,
                  currentPlan: currentPlan,
                ),

                const SizedBox(height: 12),

                // Plus 플랜
                _buildPlanCard(
                  plan: SubscriptionPlan.plus,
                  title: 'Plus',
                  price: '₩4,900',
                  priceDetail: '/월',
                  features: [
                    '월 30회 설문 시뮬레이션',
                    '고급 페르소나 커스터마이징',
                    '상세 분석 리포트',
                    'PDF 내보내기',
                  ],
                  color: Colors.blue,
                  currentPlan: currentPlan,
                  isPopular: true,
                ),

                const SizedBox(height: 12),

                // Pro 플랜
                _buildPlanCard(
                  plan: SubscriptionPlan.pro,
                  title: 'Pro',
                  price: '₩9,900',
                  priceDetail: '/월',
                  features: [
                    '무제한 설문 시뮬레이션',
                    'API 접근 권한',
                    '우선 고객 지원',
                    '팀 협업 기능',
                    '맞춤형 페르소나 모델',
                  ],
                  color: Colors.purple,
                  currentPlan: currentPlan,
                ),

                const SizedBox(height: 24),

                // 결제 버튼
                if (_selectedPlan != null && _selectedPlan != currentPlan)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: userProvider.isLoading
                          ? null
                          : () => _processPayment(context, _selectedPlan!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: userProvider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _selectedPlan == SubscriptionPlan.free
                                  ? '무료 플랜으로 변경'
                                  : '${_getPlanName(_selectedPlan!)} 구독하기',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                const SizedBox(height: 24),

                // 안내 문구
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '안전한 결제',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• 언제든지 구독을 취소할 수 있습니다\n• 결제일 기준 30일간 이용 가능\n• 카드 정보는 안전하게 암호화됩니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required String title,
    required String price,
    required String priceDetail,
    required List<String> features,
    required Color color,
    required SubscriptionPlan currentPlan,
    bool isPopular = false,
  }) {
    final isSelected = _selectedPlan == plan;
    final isCurrent = currentPlan == plan;

    return GestureDetector(
      onTap: isCurrent ? null : () => setState(() => _selectedPlan = plan),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 플랜 이름
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '인기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '현재',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                // 선택 표시
                if (!isCurrent)
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? color : Colors.grey,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 가격
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (priceDetail.isNotEmpty)
                  Text(
                    priceDetail,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 기능 목록
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: color, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        feature,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _getPlanName(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.plus:
        return 'Plus';
      case SubscriptionPlan.pro:
        return 'Pro';
    }
  }

  void _processPayment(BuildContext context, SubscriptionPlan plan) async {
    // 결제 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구독 확인'),
        content: Text(
          plan == SubscriptionPlan.free
              ? 'Free 플랜으로 변경하시겠습니까?'
              : '${_getPlanName(plan)} 플랜을 구독하시겠습니까?\n\n${plan == SubscriptionPlan.plus ? "₩4,900" : "₩9,900"}/월이 결제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 결제 처리 (더미)
    final userProvider = context.read<UserProvider>();
    final success = await userProvider.upgradePlan(plan);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getPlanName(plan)} 플랜으로 변경되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('결제 처리 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
