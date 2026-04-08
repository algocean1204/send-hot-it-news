import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/manual_trigger_provider.dart';
import 'trigger_result_dialog.dart';

// ============================================================
// F02: 수동 트리거 버튼 위젯
// 실행 중 CircularProgressIndicator를 표시하고, 완료 시 결과 다이얼로그를 띄운다
// ============================================================

class ManualTriggerButton extends ConsumerWidget {
  const ManualTriggerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(manualTriggerProvider);

    // 완료/오류 상태 전환 시 다이얼로그를 띄운다
    ref.listen<TriggerStatus>(manualTriggerProvider, (prev, next) {
      if (next.state == TriggerState.done || next.state == TriggerState.error) {
        showDialog(
          context: context,
          builder: (_) => TriggerResultDialog(status: next),
        ).then((_) => ref.read(manualTriggerProvider.notifier).reset());
      }
    });

    final isRunning = status.state == TriggerState.running;

    return ElevatedButton(
      onPressed: isRunning ? null : () => ref.read(manualTriggerProvider.notifier).run(),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        disabledBackgroundColor: AppColors.surfaceTertiary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRunning)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textSecondary,
              ),
            )
          else
            const Icon(Icons.play_arrow, size: 16),
          const SizedBox(width: 6),
          Text(
            isRunning ? '실행 중...' : '지금 실행',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
