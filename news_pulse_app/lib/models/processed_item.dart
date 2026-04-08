import 'dart:convert';

// ============================================================
// processed_items 테이블 모델
// 처리 완료된 뉴스 아이템을 표현한다
// ============================================================

class ProcessedItem {
  final int id;
  final String urlHash;
  final String url;
  final String title;
  final String source;
  final String language;
  final String? rawContent;
  final String? summaryKo;
  final List<String> tags;
  final int upvotes;
  final bool isHot;
  final String? pipelinePath;
  final int? processingTimeMs;
  final bool telegramSent;
  final String createdAt;
  // F03: 읽음 상태 — DB 마이그레이션으로 추가된 컬럼
  final bool isRead;
  // F04: 모델 추적 — 요약/번역에 사용된 모델명을 기록한다
  final String? summarizerModel;
  final String? translatorModel;

  const ProcessedItem({
    required this.id,
    required this.urlHash,
    required this.url,
    required this.title,
    required this.source,
    required this.language,
    this.rawContent,
    this.summaryKo,
    required this.tags,
    required this.upvotes,
    required this.isHot,
    this.pipelinePath,
    this.processingTimeMs,
    required this.telegramSent,
    required this.createdAt,
    this.isRead = false,
    this.summarizerModel,
    this.translatorModel,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory ProcessedItem.fromMap(Map<String, dynamic> map) {
    // tags 컬럼은 JSON 배열 문자열로 저장되어 있으므로 파싱한다
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

    return ProcessedItem(
      id: map['id'] as int,
      urlHash: map['url_hash'] as String,
      url: map['url'] as String,
      title: map['title'] as String,
      source: map['source'] as String,
      language: map['language'] as String? ?? 'en',
      rawContent: map['raw_content'] as String?,
      summaryKo: map['summary_ko'] as String?,
      tags: parsedTags,
      upvotes: map['upvotes'] as int? ?? 0,
      isHot: (map['is_hot'] as int? ?? 0) == 1,
      pipelinePath: map['pipeline_path'] as String?,
      processingTimeMs: map['processing_time_ms'] as int?,
      telegramSent: (map['telegram_sent'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String,
      // is_read 컬럼이 없는 구버전 DB를 위해 기본값 0을 사용한다
      isRead: (map['is_read'] as int? ?? 0) == 1,
      summarizerModel: map['summarizer_model'] as String?,
      translatorModel: map['translator_model'] as String?,
    );
  }
}
