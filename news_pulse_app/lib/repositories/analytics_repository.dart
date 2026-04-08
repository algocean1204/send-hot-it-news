import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ============================================================
// 분석 데이터 접근 레이어 — 블랙리스트 제안 / 임계값 교정에 필요한 집계 쿼리를 담당한다
// 기존 processed_items / filter_config 데이터를 집계해 활용한다
// ============================================================

/// 블랙리스트 제안용 단어-빈도 쌍
class WordFrequency {
  final String word;
  final int count;

  const WordFrequency({required this.word, required this.count});
}

/// 소스별 통과율 데이터
class SourcePassRate {
  final String source;
  final int totalCount;
  final int sentCount;
  final double passRate; // 0.0 ~ 1.0

  const SourcePassRate({
    required this.source,
    required this.totalCount,
    required this.sentCount,
    required this.passRate,
  });
}

class AnalyticsRepository {
  final Database _db;

  AnalyticsRepository(this._db);

  /// 최근 30일 필터링된 아이템의 제목 단어 빈도를 분석해 블랙리스트 제안 목록을 반환한다
  /// telegram_sent=0 AND created_at < 하루 전 조건으로 근사한다
  Future<List<WordFrequency>> getFilteredWordFrequency({int topN = 20}) async {
    // 제목 전체를 가져와 앱에서 단어 분리 + 집계를 수행한다
    // SQL에서 단어 단위 분리가 어려우므로 Dart에서 처리한다
    final maps = await _db.rawQuery(
      "SELECT title FROM processed_items "
      "WHERE telegram_sent = 0 "
      "AND created_at < datetime('now', '-1 day', 'localtime') "
      "ORDER BY created_at DESC LIMIT 500",
    );
    final freq = <String, int>{};
    for (final row in maps) {
      final title = (row['title'] as String? ?? '').toLowerCase();
      // 공백·특수문자로 분리 후 3글자 이상 단어만 집계한다
      final words = title.split(RegExp(r'[\s\W]+'));
      for (final w in words) {
        if (w.length >= 3) {
          freq[w] = (freq[w] ?? 0) + 1;
        }
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(topN)
        .map((e) => WordFrequency(word: e.key, count: e.value))
        .toList();
  }

  /// 소스별 최근 30일 통과율을 반환한다
  Future<List<SourcePassRate>> getPassRateBySource() async {
    final maps = await _db.rawQuery(
      "SELECT source, "
      "COUNT(*) AS total_count, "
      "SUM(telegram_sent) AS sent_count "
      "FROM processed_items "
      "WHERE created_at >= datetime('now', '-30 days', 'localtime') "
      "GROUP BY source "
      "ORDER BY source ASC",
    );
    return maps.map((row) {
      final total = (row['total_count'] as int?) ?? 0;
      final sent = (row['sent_count'] as int?) ?? 0;
      final rate = total > 0 ? sent / total : 0.0;
      return SourcePassRate(
        source: row['source'] as String? ?? '',
        totalCount: total,
        sentCount: sent,
        passRate: rate,
      );
    }).toList();
  }
}
