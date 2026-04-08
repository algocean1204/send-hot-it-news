import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/health_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'health_result_card.dart';

// ============================================================
// 헬스체크 패널 — 시스템 상태 확인 및 수동 실행 UI
// ============================================================

class HealthCheckPanel extends ConsumerWidget {
  const HealthCheckPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(latestHealthResultsProvider);
    final isRunning = ref.watch(healthCheckRunningProvider);
    final message = ref.watch(healthCheckMessageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헬스체크 실행 버튼 영역
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: isRunning ? null : () => _runHealthCheck(context, ref),
                icon: isRunning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.health_and_safety_outlined, size: 16),
                label: Text(isRunning ? '실행 중...' : '헬스체크 실행'),
              ),
              const SizedBox(width: 12),
              // Row 안에서 메시지가 넘치지 않도록 Expanded로 감싼다
              if (message != null)
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: message.contains('완료') ? AppColors.success : AppColors.error,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              const Spacer(),
              IconButton(
                onPressed: () => ref.invalidate(latestHealthResultsProvider),
                icon: Icon(Icons.refresh, size: 16, color: AppColors.textSecondary),
                tooltip: '새로고침',
              ),
            ],
          ),
        ),
        Divider(color: AppColors.border, height: 1),
        // 헬스체크 결과 목록
        Expanded(
          child: resultsAsync.when(
            data: (results) {
              if (results.isEmpty) {
                return Center(
                  child: Text(
                    '헬스체크 결과가 없습니다\n상단 버튼으로 실행하세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  HealthSummaryBar(results: results),
                  const SizedBox(height: 16),
                  ...results.map((r) => HealthResultCard(result: r)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('오류: $e', style: TextStyle(color: AppColors.error)),
            ),
          ),
        ),
      ],
    );
  }

  /// Python subprocess를 통해 헬스체크를 실행한다
  Future<void> _runHealthCheck(BuildContext context, WidgetRef ref) async {
    ref.read(healthCheckRunningProvider.notifier).state = true;
    ref.read(healthCheckMessageProvider.notifier).state = null;

    final repoAsync = ref.read(healthRepositoryProvider);
    await repoAsync.when(
      data: (repo) async {
        final result = await repo.runHealthCheck();
        if (context.mounted) {
          ref.read(healthCheckRunningProvider.notifier).state = false;
          ref.read(healthCheckMessageProvider.notifier).state = result.success
              ? '헬스체크 완료'
              : '실행 실패: ${result.stderr.substring(0, result.stderr.length.clamp(0, 80))}';
          // 결과 갱신
          ref.invalidate(latestHealthResultsProvider);
        }
      },
      loading: () async {},
      error: (e, _) async {
        ref.read(healthCheckRunningProvider.notifier).state = false;
        ref.read(healthCheckMessageProvider.notifier).state = '오류: $e';
      },
    );
  }
}
