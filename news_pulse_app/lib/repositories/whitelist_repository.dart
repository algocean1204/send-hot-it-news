import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/whitelist_keyword.dart';

// ============================================================
// 화이트리스트 키워드 데이터 접근 레이어 — whitelist_keywords 테이블 담당
// ============================================================

class WhitelistRepository {
  final Database _db;

  WhitelistRepository(this._db);

  /// 모든 화이트리스트 키워드를 조회한다
  Future<List<WhitelistKeyword>> getAll() async {
    final maps = await _db.rawQuery(
      'SELECT * FROM whitelist_keywords ORDER BY created_at DESC',
    );
    return maps.map(WhitelistKeyword.fromMap).toList();
  }

  /// 새 키워드를 추가한다 — 소문자 정규화 후 저장한다
  Future<void> add(String keyword) async {
    final normalized = keyword.toLowerCase().trim();
    if (normalized.isEmpty) return;
    await _db.rawInsert(
      "INSERT OR IGNORE INTO whitelist_keywords (keyword) VALUES (?)",
      [normalized],
    );
  }

  /// 특정 ID의 키워드를 삭제한다
  Future<void> delete(int id) async {
    await _db.rawDelete(
      'DELETE FROM whitelist_keywords WHERE id = ?',
      [id],
    );
  }
}
