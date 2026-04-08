import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/processed_item.dart';
import '../models/hot_news.dart';
import '../core/database/tables.dart';

// ============================================================
// 뉴스 데이터 접근 레이어 — processed_items + hot_news 테이블 담당
// 화면에서 직접 SQL을 쓰지 않도록 모든 쿼리를 이 클래스에 집중한다
// ============================================================

class NewsRepository {
  final Database _db;

  NewsRepository(this._db);

  /// 오늘 텔레그램으로 전송된 뉴스 건수를 조회한다
  Future<int> getTodaySentCount() async {
    final result = await _db.rawQuery(
      "SELECT COUNT(*) as cnt FROM ${Tables.processedItems} "
      "WHERE telegram_sent=1 AND date(created_at)=date('now','localtime')",
    );
    return result.first['cnt'] as int? ?? 0;
  }

  /// 특정 날짜의 뉴스 목록을 조회한다 (날짜별 뉴스 화면용)
  Future<List<ProcessedItem>> getItemsByDate(String date) async {
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.processedItems} "
      "WHERE date(created_at)=? ORDER BY created_at DESC",
      [date],
    );
    return maps.map(ProcessedItem.fromMap).toList();
  }

  /// 모든 핫뉴스를 최신순으로 조회한다
  Future<List<HotNews>> getAllHotNews() async {
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.hotNews} ORDER BY created_at DESC",
    );
    return maps.map(HotNews.fromMap).toList();
  }

  /// 뉴스 아이템을 핫으로 지정한다 — is_hot 업데이트 + hot_news INSERT
  Future<void> markAsHot(ProcessedItem item) async {
    await _db.transaction((txn) async {
      // processed_items 테이블의 is_hot 플래그 업데이트
      await txn.rawUpdate(
        "UPDATE ${Tables.processedItems} SET is_hot=1 WHERE id=?",
        [item.id],
      );
      // hot_news 테이블에 데이터 삽입 (영구 보관 목적)
      await txn.rawInsert(
        "INSERT OR IGNORE INTO ${Tables.hotNews} "
        "(processed_item_id, url, title, source, summary_ko, tags, upvotes, hot_reason, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, 'manual', datetime('now','localtime'))",
        [
          item.id,
          item.url,
          item.title,
          item.source,
          item.summaryKo ?? '',
          item.tags.toString(),
          item.upvotes,
        ],
      );
    });
  }

  /// 뉴스 아이템의 핫 지정을 해제한다 — is_hot 업데이트 + hot_news DELETE
  Future<void> unmarkAsHot(int processedItemId) async {
    await _db.transaction((txn) async {
      await txn.rawUpdate(
        "UPDATE ${Tables.processedItems} SET is_hot=0 WHERE id=?",
        [processedItemId],
      );
      await txn.rawDelete(
        "DELETE FROM ${Tables.hotNews} WHERE processed_item_id=?",
        [processedItemId],
      );
    });
  }

  /// 소스별/날짜별 뉴스 건수를 조회한다 (통계 화면용, 최근 7일)
  Future<List<Map<String, dynamic>>> getSourceCountByDay() async {
    return _db.rawQuery(
      "SELECT source, date(created_at,'localtime') as d, COUNT(*) as cnt "
      "FROM ${Tables.processedItems} "
      "WHERE created_at >= datetime('now','-7 days','localtime') "
      "GROUP BY source, d "
      "ORDER BY d ASC, source ASC",
    );
  }

  /// 파이프라인 경로별 뉴스 건수를 조회한다 (통계 화면용)
  Future<List<Map<String, dynamic>>> getPipelinePathCount() async {
    return _db.rawQuery(
      "SELECT pipeline_path, COUNT(*) as cnt "
      "FROM ${Tables.processedItems} "
      "WHERE pipeline_path IS NOT NULL "
      "GROUP BY pipeline_path",
    );
  }

  // ============================================================
  // F03: 읽음 상태 관련 메서드
  // ============================================================

  /// 특정 아이템을 읽음으로 표시한다
  Future<void> markAsRead(int id) async {
    await _db.rawUpdate(
      "UPDATE ${Tables.processedItems} SET is_read=1 WHERE id=?",
      [id],
    );
  }

  /// 읽지 않은 아이템 수를 조회한다 (홈 화면 뱃지용)
  Future<int> getUnreadCount() async {
    final result = await _db.rawQuery(
      "SELECT COUNT(*) as cnt FROM ${Tables.processedItems} WHERE is_read=0",
    );
    return result.first['cnt'] as int? ?? 0;
  }

  // ============================================================
  // F10: 날짜 범위 조회 (마크다운 내보내기용)
  // ============================================================

  /// 날짜 범위로 뉴스 아이템을 조회한다 — 핫뉴스 우선, 이후 일반 뉴스 순으로 정렬
  Future<List<ProcessedItem>> getItemsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    // 핫뉴스를 먼저, 그 다음 생성 시각 내림차순으로 정렬한다
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.processedItems} "
      "WHERE date(created_at) >= date(?) AND date(created_at) <= date(?) "
      "ORDER BY is_hot DESC, created_at DESC",
      [
        start.toIso8601String().substring(0, 10),
        end.toIso8601String().substring(0, 10),
      ],
    );
    return maps.map(ProcessedItem.fromMap).toList();
  }
}
