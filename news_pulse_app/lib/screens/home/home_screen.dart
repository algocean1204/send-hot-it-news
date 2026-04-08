import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/run_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/error_provider.dart';
import '../../providers/subscriber_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/card_state_widgets.dart';
import 'widgets/status_card.dart';
import 'widgets/today_count_card.dart';
import 'widgets/recent_errors_card.dart';
import 'widgets/subscriber_count_card.dart';
import 'widgets/manual_trigger_button.dart';
import 'widgets/unread_count_card.dart';
import 'widgets/missed_run_banner.dart';

// ============================================================
// 화면 1: 홈 (Overview)
// 봇 상태, 오늘 전송 건수, 최근 에러, 다음 실행 시간, 구독자 수를 표시한다
// F02: 수동 트리거 버튼 추가
// F03: 미읽음 카드 추가
// F05: 누락 실행 배너 추가
// ============================================================

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// launchd 스케줄 기반으로 다음 실행 시각을 계산한다 (09:00~23:00 + 00:00 매시)
  String _calcNextRun() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;

    // 09:00~23:00 구간: 다음 정각을 계산한다
    if (hour >= 9 && hour <= 23) {
      final nextHour = minute == 0 ? hour : hour + 1;
      if (nextHour == 24) {
        // 23시대에서 다음 실행은 자정(00:00)이다
        final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0);
        final mins = midnight.difference(now).inMinutes;
        return '00:00 ($mins분 후)';
      }
      final nextTime = DateTime(now.year, now.month, now.day, nextHour, 0);
      final mins = nextTime.difference(now).inMinutes;
      return '${nextHour.toString().padLeft(2, '0')}:00 ($mins분 후)';
    }
    // 00:00~08:59 구간: 다음 실행은 오늘 09:00이다
    return '오늘 09:00';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestRun = ref.watch(latestRunProvider);
    final todayCount = ref.watch(todaySentCountProvider);
    final recentErrors = ref.watch(recentErrorsProvider);
    final subscriberCounts = ref.watch(subscriberCountProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final missedRunCount = ref.watch(missedRunCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // F05: 누락 실행 경고 배너 — 건수가 1 이상일 때만 표시한다
            if ((missedRunCount.valueOrNull ?? 0) > 0) ...[
              MissedRunBanner(missedCount: missedRunCount.valueOrNull!),
              const SizedBox(height: 16),
            ],
            _buildPageHeader(context, ref),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) => _buildCardGrid(
                constraints,
                latestRun,
                todayCount,
                recentErrors,
                subscriberCounts,
                unreadCount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '홈 대시보드',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
            ),
            Text(
              'news-pulse 봇 상태 및 현황',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
        _buildNextRunBadge(),
        const SizedBox(width: 8),
        // F02: 수동 실행 버튼
        const ManualTriggerButton(),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _refreshAll(ref),
          icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          tooltip: '새로고침',
        ),
      ],
    );
  }

  Widget _buildNextRunBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('다음 실행', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              Text(
                _calcNextRun(),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid(
    BoxConstraints constraints,
    AsyncValue latestRun,
    AsyncValue todayCount,
    AsyncValue recentErrors,
    AsyncValue subscriberCounts,
    AsyncValue<int> unreadCount,
  ) {
    // 소수점 픽셀을 버림해 서브픽셀 렌더링 오차를 방지한다
    final cardWidth = ((constraints.maxWidth - 16) / 2).floorToDouble();
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(width: cardWidth, child: latestRun.when(
          data: (run) => StatusCard(latestRun: run),
          loading: () => const LoadingCard(label: '봇 상태'),
          error: (e, _) => const ErrorCard(label: '봇 상태'),
        )),
        SizedBox(width: cardWidth, child: todayCount.when(
          data: (count) => TodayCountCard(sentCount: count),
          loading: () => const LoadingCard(label: '오늘 전송'),
          error: (e, _) => const ErrorCard(label: '오늘 전송'),
        )),
        SizedBox(width: cardWidth, child: recentErrors.when(
          data: (errors) => RecentErrorsCard(errors: errors),
          loading: () => const LoadingCard(label: '최근 에러'),
          error: (e, _) => const ErrorCard(label: '최근 에러'),
        )),
        SizedBox(width: cardWidth, child: subscriberCounts.when(
          data: (counts) => SubscriberCountCard(counts: counts),
          loading: () => const LoadingCard(label: '구독자 현황'),
          error: (e, _) => const ErrorCard(label: '구독자 현황'),
        )),
        // F03: 미읽음 뉴스 카드
        SizedBox(width: cardWidth, child: unreadCount.when(
          data: (count) => UnreadCountCard(count: count),
          loading: () => const LoadingCard(label: '미읽음 뉴스'),
          error: (e, _) => const ErrorCard(label: '미읽음 뉴스'),
        )),
      ],
    );
  }

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(latestRunProvider);
    ref.invalidate(todaySentCountProvider);
    ref.invalidate(recentErrorsProvider);
    ref.invalidate(subscriberCountProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(missedRunCountProvider);
  }
}
