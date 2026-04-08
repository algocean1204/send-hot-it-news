import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// F03: 미읽음 뉴스 건수 카드
// 홈 대시보드에서 읽지 않은 뉴스 건수를 표시한다
// ============================================================

class UnreadCountCard extends StatelessWidget {
  final int count;

  const UnreadCountCard({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 파란 점 — 미읽음 상태를 직관적으로 표시한다
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '미읽음 뉴스',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$count건',
            style: TextStyle(
              color: count > 0 ? AppColors.info : AppColors.textMuted,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count > 0 ? '뉴스 화면에서 확인하세요' : '모두 읽었습니다',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
