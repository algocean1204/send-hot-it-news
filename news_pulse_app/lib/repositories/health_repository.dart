import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/health_check_result.dart';
import '../core/database/tables.dart';

// ============================================================
// 헬스체크 데이터 접근 레이어 — health_check_results 테이블 담당
// subprocess 실행 + 결과 조회 모두 이 클래스에서 처리한다
// ============================================================

class HealthRepository {
  final Database _db;

  HealthRepository(this._db);

  /// 최신 헬스체크 결과 목록을 check_type별 최신값으로 조회한다
  Future<List<HealthCheckResult>> getLatestResults() async {
    // 각 check_type별 가장 최근 결과를 가져온다
    final maps = await _db.rawQuery(
      "SELECT h1.* FROM ${Tables.healthCheckResults} h1 "
      "INNER JOIN ( "
      "  SELECT check_type, MAX(created_at) as max_at "
      "  FROM ${Tables.healthCheckResults} "
      "  GROUP BY check_type "
      ") h2 ON h1.check_type=h2.check_type AND h1.created_at=h2.max_at "
      "ORDER BY h1.check_type ASC",
    );
    return maps.map(HealthCheckResult.fromMap).toList();
  }

  /// 전체 헬스체크 이력을 최신순으로 조회한다
  Future<List<HealthCheckResult>> getAllResults() async {
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.healthCheckResults} ORDER BY created_at DESC",
    );
    return maps.map(HealthCheckResult.fromMap).toList();
  }

  /// Python 헬스체크 subprocess를 실행한다
  /// 실행 후 DB에 결과가 기록되면 getLatestResults()로 읽어온다
  Future<HealthCheckRunResult> runHealthCheck() async {
    try {
      // uv run으로 Python 헬스체크 모듈을 실행한다
      final result = await Process.run(
        'uv',
        ['run', 'python', '-m', 'news_pulse', '--health-check'],
        workingDirectory: '${Platform.environment['HOME']}',
        runInShell: true,
      );
      return HealthCheckRunResult(
        success: result.exitCode == 0,
        stdout: result.stdout as String,
        stderr: result.stderr as String,
        exitCode: result.exitCode,
      );
    } catch (e) {
      return HealthCheckRunResult(
        success: false,
        stdout: '',
        stderr: e.toString(),
        exitCode: -1,
      );
    }
  }
}

/// 헬스체크 subprocess 실행 결과를 표현한다
class HealthCheckRunResult {
  final bool success;
  final String stdout;
  final String stderr;
  final int exitCode;

  const HealthCheckRunResult({
    required this.success,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
}
