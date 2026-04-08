import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/run_history.dart';
import '../core/database/tables.dart';
import '../core/constants.dart';

// ============================================================
// 실행 이력 데이터 접근 레이어 — run_history 테이블 담당
// ============================================================

class RunRepository {
  final Database _db;

  RunRepository(this._db);

  /// 가장 최근 실행 기록을 조회한다 (홈 화면 봇 상태 카드용)
  Future<RunHistory?> getLatest() async {
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.runHistory} ORDER BY started_at DESC LIMIT 1",
    );
    if (maps.isEmpty) return null;
    return RunHistory.fromMap(maps.first);
  }

  /// 최근 N건의 실행 이력을 조회한다 (실행 이력 화면용)
  Future<List<RunHistory>> getRecent({int limit = kRunHistoryLimit}) async {
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.runHistory} "
      "ORDER BY started_at DESC LIMIT ?",
      [limit],
    );
    return maps.map(RunHistory.fromMap).toList();
  }

  /// 통계 차트용 최근 실행 데이터를 조회한다
  Future<List<RunHistory>> getForStats({int limit = kStatsRunLimit}) async {
    // RunHistory.fromMap이 id, status 등 전체 컬럼을 필요로 하므로 SELECT *를 사용한다
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.runHistory} "
      "ORDER BY started_at DESC LIMIT ?",
      [limit],
    );
    return maps.map(RunHistory.fromMap).toList();
  }
}
