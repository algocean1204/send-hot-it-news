import 'package:flutter/material.dart';
import '../../../models/error_log.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 최근 에러 요약 카드 — 최근 N건의 에러를 간략히 표시한다
// ============================================================

class RecentErrorsCard extends StatelessWidget {
  final List<ErrorLog> errors;

  const RecentErrorsCard({super.key, required this.errors});

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
                Icon(Icons.warning_amber_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '최근 에러',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: errors.isEmpty
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${errors.length}건',
                    style: TextStyle(
                      color: errors.isEmpty ? AppColors.success : AppColors.error,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (errors.isEmpty)
              Text(
                '최근 에러 없음',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              )
            else
              ...errors.map((e) => _buildErrorRow(e)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorRow(ErrorLog error) {
    final severityColor = _severityColor(error.severity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 심각도 레이블
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _severityLabel(error.severity),
              style: TextStyle(
                color: severityColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '[${error.module}] ${error.message}',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  error.createdAt,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _severityLabel(ErrorSeverity s) => switch (s) {
    ErrorSeverity.info => 'INFO',
    ErrorSeverity.warning => 'WARN',
    ErrorSeverity.error => 'ERROR',
    ErrorSeverity.critical => 'CRIT',
  };

  Color _severityColor(ErrorSeverity s) => switch (s) {
    ErrorSeverity.info => AppColors.info,
    ErrorSeverity.warning => AppColors.warning,
    ErrorSeverity.error => AppColors.error,
    ErrorSeverity.critical => AppColors.critical,
  };
}
