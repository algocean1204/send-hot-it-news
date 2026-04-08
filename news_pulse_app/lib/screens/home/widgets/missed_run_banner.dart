import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// F05: 누락 실행 경고 배너
// launchd가 예정된 시간에 실행되지 않은 경우 홈 화면 상단에 표시한다
// ============================================================

class MissedRunBanner extends StatelessWidget {
  final int missedCount;

  const MissedRunBanner({super.key, required this.missedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$missedCount건의 스케줄 실행이 누락되었습니다. launchd 설정을 확인하세요.',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
