import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/subscriber_provider.dart';
import '../../providers/database_provider.dart';
import '../../repositories/subscriber_repository.dart';
import '../../models/subscriber.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/subscriber_tile.dart';
import 'widgets/subscriber_search.dart';

// ============================================================
// 화면 3: 구독자 관리
// pending/approved/rejected 탭 + 검색 + 승인/거부/삭제
// ============================================================

class SubscribersScreen extends ConsumerWidget {
  const SubscribersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 + 검색
            _buildHeader(context, ref),
            const Divider(color: AppColors.border, height: 1),
            // 탭바
            Container(
              color: AppColors.surfacePrimary,
              child: const TabBar(
                tabs: [
                  Tab(text: '대기중 (Pending)'),
                  Tab(text: '승인됨 (Approved)'),
                  Tab(text: '거부됨 (Rejected)'),
                ],
              ),
            ),
            // 탭 내용
            Expanded(
              child: TabBarView(
                children: [
                  _SubscriberListTab(status: SubscriberStatus.pending),
                  _SubscriberListTab(status: SubscriberStatus.approved),
                  _SubscriberListTab(status: SubscriberStatus.rejected),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('구독자 관리', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
              Text('텔레그램 구독 신청 승인 및 관리', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          const Spacer(),
          SubscriberSearch(
            onSearch: (query) => ref.read(subscriberSearchQueryProvider.notifier).state = query,
          ),
        ],
      ),
    );
  }
}

/// 상태별 구독자 목록 탭
class _SubscriberListTab extends ConsumerWidget {
  final SubscriberStatus status;

  const _SubscriberListTab({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(subscriberSearchQueryProvider);

    // 검색어가 있으면 검색 결과를, 없으면 상태별 목록을 표시한다
    if (searchQuery.isNotEmpty) {
      return ref.watch(subscriberSearchResultProvider).when(
        data: (items) => _buildList(context, ref, items.where((s) => s.status == status).toList()),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e', style: const TextStyle(color: AppColors.error))),
      );
    }

    return ref.watch(subscribersByStatusProvider(status)).when(
      data: (items) => _buildList(context, ref, items),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('오류: $e', style: const TextStyle(color: AppColors.error)),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<Subscriber> subscribers) {
    if (subscribers.isEmpty) {
      return const Center(
        child: Text(
          '해당하는 구독자가 없습니다',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      itemCount: subscribers.length,
      itemBuilder: (context, index) {
        final sub = subscribers[index];
        return SubscriberTile(
          subscriber: sub,
          onApprove: status == SubscriberStatus.pending
              ? () => _approve(context, ref, sub.chatId)
              : null,
          onReject: status == SubscriberStatus.pending
              ? () => _reject(context, ref, sub.chatId)
              : null,
          onDelete: () => _confirmDelete(context, ref, sub),
        );
      },
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, int chatId) async {
    await _withRepo(context, ref, (repo) => repo.approve(chatId));
    _invalidate(ref);
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, int chatId) async {
    await _withRepo(context, ref, (repo) => repo.reject(chatId));
    _invalidate(ref);
  }

  /// 삭제 전 확인 다이얼로그를 표시한다
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Subscriber sub) async {
    final confirmed = await _showDeleteDialog(context, sub.displayName);
    // 다이얼로그 대기 후 위젯이 여전히 마운트 상태인지 확인한다
    if (confirmed == true && context.mounted) {
      await _withRepo(context, ref, (repo) => repo.delete(sub.chatId));
      _invalidate(ref);
    }
  }

  Future<bool?> _showDeleteDialog(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfacePrimary,
        title: const Text('구독자 삭제', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '$name을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// DB 오류 발생 시 SnackBar로 사용자에게 오류 메시지를 표시한다
  Future<void> _withRepo(BuildContext context, WidgetRef ref, Future<void> Function(SubscriberRepository) action) async {
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) => action(SubscriberRepository(db)),
      loading: () async {},
      error: (e, _) async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류: $e')),
          );
        }
      },
    );
  }

  void _invalidate(WidgetRef ref) {
    ref.invalidate(subscribersByStatusProvider);
    ref.invalidate(subscriberCountProvider);
    ref.invalidate(subscriberSearchResultProvider);
  }
}
