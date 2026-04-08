import 'package:flutter/material.dart';
import '../../../models/run_history.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 실행 이력 상세 타일 — 파이프라인 실행 한 건의 결과를 표시한다
// ============================================================

class RunDetailTile extends StatelessWidget {
  final RunHistory run;

  const RunDetailTile({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 첫 번째 행: 시작 시각 + 상태 배지 + 소요시간
          Row(
            children: [
              // 상태 아이콘
              Icon(
                _statusIcon(run.status),
                size: 16,
                color: _statusColor(run.status),
              ),
              const SizedBox(width: 8),
              Text(
                run.startedAt,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 10),
              _buildStatusBadge(),
              const Spacer(),
              Text(
                run.durationDisplay,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 두 번째 행: 수집/필터/요약/전송 건수 — 좁은 윈도우에서 넘치지 않도록 가로 스크롤을 허용한다
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _countChip('수집', run.fetchedCount, AppColors.info),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_right, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 8),
                _countChip('필터', run.filteredCount, AppColors.accent),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_right, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 8),
                _countChip('요약', run.summarizedCount, AppColors.warning),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_right, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 8),
                _countChip('전송', run.sentCount, AppColors.success),
                const SizedBox(width: 12),
                if (run.memoryMode != null)
                  _modeTag(run.memoryMode!),
              ],
            ),
          ),
          // 세 번째 행: 세부 소요시간 (있는 경우)
          if (run.modelLoadMs != null || run.inferenceMs != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (run.modelLoadMs != null)
                  Text(
                    '모델 로드: ${(run.modelLoadMs! / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                if (run.modelLoadMs != null && run.inferenceMs != null)
                  const Text('  ·  ', style: TextStyle(color: AppColors.textMuted)),
                if (run.inferenceMs != null)
                  Text(
                    '추론: ${(run.inferenceMs! / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ],
          // 에러 메시지 (실패 시)
          if (run.errorMessage != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                run.errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final color = _statusColor(run.status);
    final label = _statusLabel(run.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _modeTag(String mode) {
    final isLocal = mode == 'local_llm';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: (isLocal ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        isLocal ? 'local_llm' : 'claude_fallback',
        style: TextStyle(
          color: isLocal ? AppColors.success : AppColors.warning,
          fontSize: 10,
        ),
      ),
    );
  }

  IconData _statusIcon(RunStatus s) => switch (s) {
    RunStatus.success => Icons.check_circle_outline,
    RunStatus.running => Icons.pending_outlined,
    RunStatus.partialFailure => Icons.warning_amber_outlined,
    RunStatus.failure => Icons.error_outline,
  };

  String _statusLabel(RunStatus s) => switch (s) {
    RunStatus.success => 'SUCCESS',
    RunStatus.running => 'RUNNING',
    RunStatus.partialFailure => 'PARTIAL',
    RunStatus.failure => 'FAILURE',
  };

  Color _statusColor(RunStatus s) => switch (s) {
    RunStatus.success => AppColors.success,
    RunStatus.running => AppColors.info,
    RunStatus.partialFailure => AppColors.warning,
    RunStatus.failure => AppColors.error,
  };
}
