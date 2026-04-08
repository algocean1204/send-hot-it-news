import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 구독자 수 카드 — 상태별 구독자 수를 표시한다
// ============================================================

class SubscriberCountCard extends StatelessWidget {
  final Map<String, int> counts;

  const SubscriberCountCard({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final pending = counts['pending'] ?? 0;
    final approved = counts['approved'] ?? 0;
    final rejected = counts['rejected'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people_outline, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  '구독자 현황',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCountItem('승인', approved, AppColors.success),
                _buildDivider(),
                _buildCountItem('대기', pending, AppColors.warning),
                _buildDivider(),
                _buildCountItem('거부', rejected, AppColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.border,
    );
  }
}
