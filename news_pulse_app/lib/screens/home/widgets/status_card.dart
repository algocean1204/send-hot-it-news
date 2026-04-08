import 'package:flutter/material.dart';
import '../../../models/run_history.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 봇 상태 카드 — 마지막 실행 결과와 상태를 표시한다
// ============================================================

class StatusCard extends StatelessWidget {
  final RunHistory? latestRun;

  const StatusCard({super.key, this.latestRun});

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
                const Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  '봇 상태',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // 상태 배지
                if (latestRun != null) _buildStatusBadge(latestRun!.status),
              ],
            ),
            const SizedBox(height: 16),
            if (latestRun == null)
              const Text(
                '실행 기록 없음',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              )
            else ...[
              Text(
                _statusLabel(latestRun!.status),
                style: TextStyle(
                  color: _statusColor(latestRun!.status),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '마지막 실행: ${latestRun!.startedAt}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              if (latestRun!.finishedAt != null)
                Text(
                  '완료: ${latestRun!.finishedAt} (${latestRun!.durationDisplay})',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(RunStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _statusColor(status).withValues(alpha: 0.4)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: _statusColor(status),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _statusLabel(RunStatus status) => switch (status) {
    RunStatus.success => 'SUCCESS',
    RunStatus.running => 'RUNNING',
    RunStatus.partialFailure => 'PARTIAL',
    RunStatus.failure => 'FAILURE',
  };

  Color _statusColor(RunStatus status) => switch (status) {
    RunStatus.success => AppColors.success,
    RunStatus.running => AppColors.info,
    RunStatus.partialFailure => AppColors.warning,
    RunStatus.failure => AppColors.error,
  };
}
