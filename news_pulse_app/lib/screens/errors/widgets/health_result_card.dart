import 'package:flutter/material.dart';
import '../../../models/health_check_result.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 헬스체크 결과 카드 — 개별 체크 결과 및 전체 요약 렌더링
// ============================================================

/// 전체 헬스체크 결과 요약 위젯 (정상/경고/오류 카운트)
class HealthSummaryBar extends StatelessWidget {
  final List<HealthCheckResult> results;

  const HealthSummaryBar({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    final okCount = results.where((r) => r.status == HealthStatus.ok).length;
    final warnCount = results.where((r) => r.status == HealthStatus.warning).length;
    final errCount = results.where((r) => r.status == HealthStatus.error).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            '전체 상태',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 16),
          _SummaryItem(label: '정상', count: okCount, color: AppColors.success),
          const SizedBox(width: 12),
          _SummaryItem(label: '경고', count: warnCount, color: AppColors.warning),
          const SizedBox(width: 12),
          _SummaryItem(label: '오류', count: errCount, color: AppColors.error),
        ],
      ),
    );
  }
}

/// 요약 항목 하나 (아이콘 + 레이블 + 카운트)
class _SummaryItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 4),
        Text(
          '$label $count',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// 개별 헬스체크 결과 카드 위젯
class HealthResultCard extends StatelessWidget {
  final HealthCheckResult result;

  const HealthResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(result.status);
    final statusIcon = _statusIcon(result.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 18, color: statusColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    result.checkType,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.target,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              if (result.message != null)
                Text(
                  result.message!,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
            ],
          ),
          const Spacer(),
          if (result.responseTimeMs != null)
            Text(
              '${result.responseTimeMs}ms',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }

  IconData _statusIcon(HealthStatus s) => switch (s) {
    HealthStatus.ok => Icons.check_circle_outline,
    HealthStatus.warning => Icons.warning_amber_outlined,
    HealthStatus.error => Icons.error_outline,
  };

  Color _statusColor(HealthStatus s) => switch (s) {
    HealthStatus.ok => AppColors.success,
    HealthStatus.warning => AppColors.warning,
    HealthStatus.error => AppColors.error,
  };
}
