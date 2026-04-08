import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

// ============================================================
// 공용 카드 상태 위젯 — 로딩/에러 상태를 카드 형태로 표시한다
// ============================================================

/// 로딩 중 플레이스홀더 카드
class LoadingCard extends StatelessWidget {
  final String label;

  const LoadingCard({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              backgroundColor: AppColors.surfaceSecondary,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// 에러 플레이스홀더 카드
class ErrorCard extends StatelessWidget {
  final String label;

  const ErrorCard({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            const Text('데이터 로드 실패', style: TextStyle(color: AppColors.error, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
