import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/error_log.dart';
import '../core/database/tables.dart';
import '../core/constants.dart';

// ============================================================
// 에러 로그 데이터 접근 레이어 — error_log 테이블 담당
// ============================================================

class ErrorRepository {
  final Database _db;

  ErrorRepository(this._db);

  /// 최근 에러 로그를 조회한다 (홈 화면 카드용, 기본 5건)
  Future<List<ErrorLog>> getRecent({int limit = kRecentErrorsLimit}) async {
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.errorLog} ORDER BY created_at DESC LIMIT ?",
      [limit],
    );
    return maps.map(ErrorLog.fromMap).toList();
  }

  /// 심각도별 필터를 적용하여 에러 로그를 조회한다
  Future<List<ErrorLog>> getFiltered({
    String? severity,
    int limit = kErrorLogLimit,
  }) async {
    if (severity == null || severity == 'all') {
      final maps = await _db.rawQuery(
        "SELECT * FROM ${Tables.errorLog} ORDER BY created_at DESC LIMIT ?",
        [limit],
      );
      return maps.map(ErrorLog.fromMap).toList();
    }

    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.errorLog} "
      "WHERE severity=? ORDER BY created_at DESC LIMIT ?",
      [severity, limit],
    );
    return maps.map(ErrorLog.fromMap).toList();
  }
}
