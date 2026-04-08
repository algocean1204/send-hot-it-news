import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/schedule_log.dart';
import '../core/database/tables.dart';

// ============================================================
// 스케줄 로그 데이터 접근 레이어 — schedule_log 테이블 담당
// launchd 누락 실행 감지에 사용한다
// ============================================================

class ScheduleRepository {
  final Database _db;

  ScheduleRepository(this._db);

  /// 최근 24시간 내 누락된 실행 목록을 조회한다
  /// schedule_log 테이블이 없는 경우 빈 리스트를 반환한다
  Future<List<ScheduleLog>> getMissedRuns() async {
    try {
      final maps = await _db.rawQuery(
        "SELECT * FROM ${Tables.scheduleLog} "
        "WHERE status='missed' "
        "AND created_at >= datetime('now','-24 hours','localtime') "
        "ORDER BY scheduled_at DESC",
      );
      return maps.map(ScheduleLog.fromMap).toList();
    } catch (_) {
      // schedule_log 테이블이 아직 마이그레이션되지 않은 경우 빈 리스트 반환
      return [];
    }
  }

  /// 누락된 실행 건수를 조회한다 (배너 표시 여부 결정용)
  Future<int> getMissedRunCount() async {
    final missed = await getMissedRuns();
    return missed.length;
  }
}
