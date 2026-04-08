import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/news_provider.dart';
import '../../providers/database_provider.dart';
import '../../repositories/news_repository.dart';
import '../../models/processed_item.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/news_list_tile.dart';
import 'widgets/news_detail_dialog.dart';
import 'widgets/hot_news_tab.dart';
import 'widgets/export_dialog.dart';

// ============================================================
// 화면 2: 날짜별 뉴스
// 30일치 날짜 선택 + 일반/핫뉴스 탭 + 핫뉴스 수동 토글
// F10: 마크다운 내보내기 버튼 추가
// ============================================================

/// 현재 선택된 날짜 상태 Provider
final selectedNewsDateProvider = StateProvider.autoDispose<DateTime>(
  (ref) => DateTime.now(),
);

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedNewsDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, ref, selectedDate),
            Divider(color: AppColors.border, height: 1),
            Container(
              color: AppColors.surfacePrimary,
              child: const TabBar(
                tabs: [Tab(text: '일반 뉴스'), Tab(text: '핫뉴스')],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _NewsListTab(dateStr: dateStr),
                  const HotNewsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, DateTime selectedDate) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('날짜별 뉴스', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
              Text('수집된 뉴스를 날짜별로 브라우징한다', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          const Spacer(),
          // F10: 마크다운 내보내기 버튼
          OutlinedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const ExportDialog(),
            ),
            icon: const Icon(Icons.download_outlined, size: 14),
            label: const Text('내보내기', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          _buildDatePickerButton(context, ref, selectedDate),
        ],
      ),
    );
  }

  Widget _buildDatePickerButton(BuildContext context, WidgetRef ref, DateTime selectedDate) {
    return InkWell(
      onTap: () => _showDatePicker(context, ref, selectedDate),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfacePrimary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(selectedDate),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context, WidgetRef ref, DateTime selectedDate) async {
    final firstDate = DateTime.now().subtract(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(selectedNewsDateProvider.notifier).state = picked;
    }
  }
}

/// 일반 뉴스 탭 내용
class _NewsListTab extends ConsumerWidget {
  final String dateStr;
  const _NewsListTab({required this.dateStr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsByDateProvider(dateStr));

    return newsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text('해당 날짜의 뉴스가 없습니다', style: TextStyle(color: AppColors.textMuted)));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return NewsListTile(
              item: item,
              onTap: () => showDialog(context: context, builder: (_) => NewsDetailDialog(item: item)),
              onToggleHot: () => _toggleHot(context, ref, item),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e', style: TextStyle(color: AppColors.error))),
    );
  }

  Future<void> _toggleHot(BuildContext context, WidgetRef ref, ProcessedItem item) async {
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        final repo = NewsRepository(db);
        if (item.isHot) {
          await repo.unmarkAsHot(item.id);
        } else {
          await repo.markAsHot(item);
        }
        ref.invalidate(newsByDateProvider);
        ref.invalidate(hotNewsProvider);
      },
      loading: () async {},
      error: (e, _) async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
        }
      },
    );
  }
}

