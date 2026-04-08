import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/processed_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/news_repository.dart';
import 'news_detail_content.dart';

// ============================================================
// 뉴스 상세 다이얼로그 — 제목, 내용, 원문 열기 액션을 제공한다
// F03: 다이얼로그 열 때 해당 아이템을 읽음으로 표시한다
// ============================================================

class NewsDetailDialog extends ConsumerStatefulWidget {
  final ProcessedItem item;

  const NewsDetailDialog({super.key, required this.item});

  @override
  ConsumerState<NewsDetailDialog> createState() => _NewsDetailDialogState();
}

class _NewsDetailDialogState extends ConsumerState<NewsDetailDialog> {
  @override
  void initState() {
    super.initState();
    // 다이얼로그가 열리는 시점에 읽음 처리한다 — 이미 읽은 경우 불필요한 쿼리를 방지한다
    if (!widget.item.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
    }
  }

  Future<void> _markAsRead() async {
    final dbAsync = ref.read(databaseProvider);
    // AsyncValue에서 DB 인스턴스를 직접 추출해 사용한다
    final db = dbAsync.valueOrNull;
    if (db == null) return;
    final repo = NewsRepository(db);
    await repo.markAsRead(widget.item.id);
    // 목록 Provider를 무효화해 읽음 상태가 즉시 반영된다
    ref.invalidate(newsByDateProvider);
    ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      // 작은 윈도우에서 수직 오버플로가 발생하지 않도록 maxHeight를 제한한다
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (제목 + 닫기 버튼)
            _buildHeader(context),
            const Divider(color: AppColors.border, height: 1),
            // 본문 (스크롤 가능)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: NewsDetailContent(item: widget.item),
              ),
            ),
            // 하단 액션 버튼
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              widget.item.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text('닫기'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _openUrl(),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('원문 열기'),
          ),
        ],
      ),
    );
  }

  /// url_launcher로 브라우저에서 원문을 연다
  Future<void> _openUrl() async {
    final uri = Uri.tryParse(widget.item.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
