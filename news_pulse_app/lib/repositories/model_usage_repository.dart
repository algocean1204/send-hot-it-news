import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/model_usage.dart';
import '../core/database/tables.dart';

// ============================================================
// 모델 사용량 데이터 접근 레이어 — model_usage_log 테이블 담당
// 지연 추이 차트 데이터 제공에 사용한다
// ============================================================

class ModelUsageRepository {
  final Database _db;

  ModelUsageRepository(this._db);

  /// 날짜별 모델 평균 지연 시간을 조회한다 (지연 추이 차트용)
  /// model_usage_log 테이블이 없는 경우 빈 리스트를 반환한다
  Future<List<ModelLatencyPoint>> getLatencyTrending({int days = 7}) async {
    try {
      final maps = await _db.rawQuery(
        "SELECT model_name, date(created_at,'localtime') as d, "
        "AVG(latency_ms) as avg_ms "
        "FROM ${Tables.modelUsageLog} "
        "WHERE success=1 "
        "AND created_at >= datetime('now','-$days days','localtime') "
        "GROUP BY model_name, d "
        "ORDER BY d ASC, model_name ASC",
      );
      return maps
          .map(
            (m) => ModelLatencyPoint(
              modelName: m['model_name'] as String,
              date: m['d'] as String,
              avgLatencyMs: (m['avg_ms'] as num).toDouble(),
            ),
          )
          .toList();
    } catch (_) {
      // model_usage_log 테이블이 아직 마이그레이션되지 않은 경우 빈 리스트 반환
      return [];
    }
  }
}
