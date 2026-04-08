import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/manual_trigger_provider.dart';

// ============================================================
// F02: 수동 트리거 결과 다이얼로그
// 실행 완료 후 가져온 건수, 요약 건수, 전송 건수를 표시한다
// ============================================================

class TriggerResultDialog extends StatelessWidget {
  final TriggerStatus status;

  const TriggerResultDialog({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isError = status.state == TriggerState.error;
    return Dialog(
      backgroundColor: AppColors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(isError),
              const SizedBox(height: 16),
              isError ? _buildErrorBody() : _buildSuccessBody(),
              const SizedBox(height: 20),
              _buildCloseButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(bool isError) {
    return Row(
      children: [
        Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? AppColors.error : AppColors.success,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          isError ? '실행 실패' : '실행 완료',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBody() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.errorMessage ?? '알 수 없는 오류가 발생했습니다',
        style: TextStyle(color: AppColors.error, fontSize: 12),
      ),
    );
  }

  Widget _buildSuccessBody() {
    final result = status.result;
    if (result == null) {
      return Text(
        '파이프라인이 완료되었습니다',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }
    return Column(
      children: [
        _ResultRow(label: '수집', count: result.fetched, icon: Icons.download),
        const SizedBox(height: 8),
        _ResultRow(label: '필터링', count: result.filtered, icon: Icons.filter_list),
        const SizedBox(height: 8),
        _ResultRow(label: '요약', count: result.summarized, icon: Icons.summarize),
        const SizedBox(height: 8),
        _ResultRow(label: '전송', count: result.sent, icon: Icons.send, highlight: true),
      ],
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('확인'),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool highlight;

  const _ResultRow({
    required this.label,
    required this.count,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          '$count건',
          style: TextStyle(
            color: highlight ? AppColors.success : AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
