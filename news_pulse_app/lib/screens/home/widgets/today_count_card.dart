import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 오늘 전송 건수 카드 — 오늘 텔레그램으로 전송된 뉴스 수를 표시한다
// ============================================================

class TodayCountCard extends StatelessWidget {
  final int sentCount;

  const TodayCountCard({super.key, required this.sentCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.send_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '오늘 전송',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$sentCount',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '건 텔레그램 전송',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
