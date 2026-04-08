import 'dart:convert';

// ============================================================
// hot_news 테이블 모델
// 핫뉴스로 판정된 아이템을 영구 보관한다
// ============================================================

class HotNews {
  final int id;
  // nullable — Python 파이프라인이 processed_item_id 없이 삽입하거나,
  // processed_items가 30일 후 삭제되면 ON DELETE SET NULL로 NULL이 된다
  final int? processedItemId;
  final String url;
  final String title;
  final String source;
  final String summaryKo;
  final List<String> tags;
  final int upvotes;
  final String hotReason;
  final String createdAt;

  const HotNews({
    required this.id,
    this.processedItemId,
    required this.url,
    required this.title,
    required this.source,
    required this.summaryKo,
    required this.tags,
    required this.upvotes,
    required this.hotReason,
    required this.createdAt,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory HotNews.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    final rawTags = map['tags'];
    if (rawTags != null && rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        // JSON 파싱 실패 시 빈 리스트로 처리
      }
    }

    return HotNews(
      id: map['id'] as int,
      processedItemId: map['processed_item_id'] as int?,
      url: map['url'] as String,
      title: map['title'] as String,
      source: map['source'] as String,
      summaryKo: map['summary_ko'] as String,
      tags: parsedTags,
      upvotes: map['upvotes'] as int? ?? 0,
      hotReason: map['hot_reason'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
