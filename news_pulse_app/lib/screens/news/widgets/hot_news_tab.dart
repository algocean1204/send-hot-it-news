import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/news_repository.dart';
import '../../../core/theme/app_theme.dart';
import 'hot_news_badge.dart';

// ============================================================
// 핫뉴스 탭 — 핫뉴스 목록 및 수동 지정 해제 기능
// ============================================================

class HotNewsTab extends ConsumerWidget {
  const HotNewsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotNewsAsync = ref.watch(hotNewsProvider);

    return hotNewsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text('핫뉴스가 없습니다', style: TextStyle(color: AppColors.textMuted)),
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return HotNewsBadge(
              item: item,
              // URL을 기본 브라우저로 열어 원문을 확인한다
              onTap: () => _openUrl(item.url),
              // 수동 지정 + processed_item_id가 존재하는 경우에만 해제 버튼을 표시한다
              onRemove: item.hotReason == 'manual' && item.processedItemId != null
                  ? () => _removeHot(ref, item.processedItemId!)
                  : null,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('오류: $e', style: TextStyle(color: AppColors.error))),
    );
  }

  /// URL을 기본 브라우저로 열어 원문 기사를 표시한다
  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 수동 핫뉴스 지정을 해제하고 프로바이더를 갱신한다
  Future<void> _removeHot(WidgetRef ref, int processedItemId) async {
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        await NewsRepository(db).unmarkAsHot(processedItemId);
        ref.invalidate(hotNewsProvider);
        ref.invalidate(newsByDateProvider);
      },
      loading: () async {},
      // DB가 오류 상태일 때 ref를 통해 에러 메시지를 표시한다
      error: (e, _) async {
        debugPrint('핫뉴스 해제 오류: $e');
      },
    );
  }
}
