import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/subscriber.dart';
import '../core/database/tables.dart';

// ============================================================
// 구독자 데이터 접근 레이어 — subscribers 테이블 담당
// ============================================================

class SubscriberRepository {
  final Database _db;

  SubscriberRepository(this._db);

  /// 특정 상태의 구독자 목록을 신청 시각 역순으로 조회한다
  Future<List<Subscriber>> getByStatus(SubscriberStatus status) async {
    final statusStr = switch (status) {
      SubscriberStatus.approved => 'approved',
      SubscriberStatus.rejected => 'rejected',
      SubscriberStatus.pending => 'pending',
    };
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.subscribers} "
      "WHERE status=? ORDER BY requested_at DESC",
      [statusStr],
    );
    return maps.map(Subscriber.fromMap).toList();
  }

  /// 상태별 구독자 수를 집계하여 반환한다 (홈 화면 카드용)
  Future<Map<String, int>> getCountByStatus() async {
    final result = await _db.rawQuery(
      "SELECT status, COUNT(*) as cnt FROM ${Tables.subscribers} GROUP BY status",
    );
    final counts = <String, int>{};
    for (final row in result) {
      counts[row['status'] as String] = row['cnt'] as int;
    }
    return counts;
  }

  /// 구독자를 승인한다 — status를 approved로 변경하고 approved_at을 기록한다
  Future<void> approve(int chatId) async {
    await _db.rawUpdate(
      "UPDATE ${Tables.subscribers} "
      "SET status='approved', approved_at=datetime('now','localtime') "
      "WHERE chat_id=?",
      [chatId],
    );
  }

  /// 구독자를 거부한다 — status를 rejected로 변경하고 rejected_at을 기록한다
  Future<void> reject(int chatId) async {
    await _db.rawUpdate(
      "UPDATE ${Tables.subscribers} "
      "SET status='rejected', rejected_at=datetime('now','localtime') "
      "WHERE chat_id=?",
      [chatId],
    );
  }

  /// 구독자를 삭제한다 (되돌릴 수 없으므로 UI에서 확인 다이얼로그 후 호출해야 함)
  Future<void> delete(int chatId) async {
    await _db.rawDelete(
      "DELETE FROM ${Tables.subscribers} WHERE chat_id=?",
      [chatId],
    );
  }

  /// username 또는 chat_id로 구독자를 검색한다
  Future<List<Subscriber>> search(String query) async {
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.subscribers} "
      "WHERE username LIKE ? OR CAST(chat_id AS TEXT) LIKE ? "
      "ORDER BY requested_at DESC",
      ['%$query%', '%$query%'],
    );
    return maps.map(Subscriber.fromMap).toList();
  }
}
