import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/news_provider.dart';
import '../../providers/run_provider.dart';
import '../../providers/model_usage_provider.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/source_chart.dart';
import 'widgets/pipeline_chart.dart';
import 'widgets/duration_chart.dart';
import 'widgets/filter_efficiency_card.dart';
import 'widgets/latency_chart.dart';

// ============================================================
// 화면 6: 통계 대시보드
// 소스별 건수, 파이프라인 경로, 응답 시간 추이, 필터링 효율 시각화
// F06: 모델별 지연 추이 차트 추가
// ============================================================

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceCountAsync = ref.watch(sourceCountByDayProvider);
    final pipelineCountAsync = ref.watch(pipelinePathCountProvider);
    final statsRunsAsync = ref.watch(statsRunsProvider);
    final latencyAsync = ref.watch(latencyTrendingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(ref),
            const SizedBox(height: 24),
            // 소스별 건수 차트
            _chartCard(sourceCountAsync.when(
              data: (data) => SourceChart(data: data),
              loading: () => const _ChartLoading(),
              error: (e, _) => Text('오류: $e', style: const TextStyle(color: AppColors.error)),
            )),
            const SizedBox(height: 16),
            // 파이프라인 + 필터링 효율 (2열)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _chartCard(pipelineCountAsync.when(
                  data: (data) => PipelineChart(data: data),
                  loading: () => const _ChartLoading(),
                  error: (e, _) => Text('오류: $e', style: const TextStyle(color: AppColors.error)),
                ))),
                const SizedBox(width: 16),
                Expanded(child: statsRunsAsync.when(
                  data: (runs) => _chartCard(FilterEfficiencyCard(runs: runs
                    .map((r) => {'fetched': r.fetchedCount, 'filtered': r.filteredCount, 'sent': r.sentCount})
                    .toList())),
                  loading: () => _chartCard(const _ChartLoading()),
                  error: (e, _) => _chartCard(Text('오류: $e', style: const TextStyle(color: AppColors.error))),
                )),
              ],
            ),
            const SizedBox(height: 16),
            // 소요 시간 추이 차트
            _chartCard(statsRunsAsync.when(
              data: (runs) => DurationChart(runs: runs),
              loading: () => const _ChartLoading(),
              error: (e, _) => Text('오류: $e', style: const TextStyle(color: AppColors.error)),
            )),
            const SizedBox(height: 16),
            // F06: 모델별 지연 추이 차트
            _chartCard(latencyAsync.when(
              data: (points) => LatencyChart(data: points),
              loading: () => const _ChartLoading(),
              error: (e, _) => Text('오류: $e', style: const TextStyle(color: AppColors.error)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(WidgetRef ref) {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('통계 대시보드', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
            Text('파이프라인 실행 통계 및 수집 현황', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: () {
            ref.invalidate(sourceCountByDayProvider);
            ref.invalidate(pipelinePathCountProvider);
            ref.invalidate(statsRunsProvider);
            ref.invalidate(latencyTrendingProvider);
          },
          icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          tooltip: '새로고침',
        ),
      ],
    );
  }

  Widget _chartCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// 차트 로딩 상태 플레이스홀더
class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
  }
}
