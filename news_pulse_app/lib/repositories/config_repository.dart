import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/filter_config.dart';
import '../core/database/tables.dart';

// ============================================================
// 설정 데이터 접근 레이어 — filter_config 테이블 담당
// ============================================================

class ConfigRepository {
  final Database _db;

  ConfigRepository(this._db);

  /// 모든 설정을 조회한다
  Future<List<FilterConfig>> getAll() async {
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.filterConfig} ORDER BY key ASC",
    );
    return maps.map(FilterConfig.fromMap).toList();
  }

  /// 소스 ON/OFF 설정만 조회한다 (설정 화면 소스 토글 섹션)
  Future<List<FilterConfig>> getSourceConfigs() async {
    final maps = await _db.rawQuery(
      "SELECT * FROM ${Tables.filterConfig} WHERE key LIKE 'source_%_enabled' ORDER BY key ASC",
    );
    return maps.map(FilterConfig.fromMap).toList();
  }

  /// 특정 키의 설정 값을 업데이트한다
  Future<void> updateValue(String key, String value) async {
    await _db.rawUpdate(
      "UPDATE ${Tables.filterConfig} "
      "SET value=?, updated_at=datetime('now','localtime') "
      "WHERE key=?",
      [value, key],
    );
  }

  /// 키-값 쌍을 삽입하거나 기존 값을 갱신한다 (INSERT OR REPLACE)
  Future<void> upsert(String key, String value) async {
    final exists = await _db.rawQuery(
      "SELECT COUNT(*) AS c FROM ${Tables.filterConfig} WHERE key = ?",
      [key],
    );
    final count = (exists.first['c'] as int?) ?? 0;
    if (count > 0) {
      await updateValue(key, value);
    } else {
      await _db.rawInsert(
        "INSERT INTO ${Tables.filterConfig} (key, value, description) "
        "VALUES (?, ?, '')",
        [key, value],
      );
    }
  }

  /// 맵 형태로 모든 설정을 반환한다 (key -> FilterConfig)
  Future<Map<String, FilterConfig>> getAllAsMap() async {
    final configs = await getAll();
    return {for (final c in configs) c.key: c};
  }

  /// filter_config에서 커스텀 소스 목록을 JSON으로 조회한다
  Future<List<Map<String, dynamic>>> getCustomSources() async {
    final maps = await _db.rawQuery(
      "SELECT value FROM ${Tables.filterConfig} WHERE key = 'custom_sources' LIMIT 1",
    );
    if (maps.isEmpty) return [];
    final raw = maps.first['value'] as String? ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  /// 커스텀 소스를 추가하고 filter_config에 JSON으로 저장한다
  Future<void> saveCustomSource(Map<String, dynamic> source) async {
    final existing = await getCustomSources();
    existing.add(source);
    final encoded = jsonEncode(existing);
    // key가 없으면 INSERT, 있으면 UPDATE한다
    final count = await _db.rawQuery(
      "SELECT COUNT(*) AS c FROM ${Tables.filterConfig} WHERE key = 'custom_sources'",
    );
    final exists = (count.first['c'] as int?) ?? 0;
    if (exists > 0) {
      await updateValue('custom_sources', encoded);
    } else {
      await _db.rawInsert(
        "INSERT INTO ${Tables.filterConfig} (key, value, description) VALUES ('custom_sources', ?, '사용자 추가 소스 목록 (JSON 배열)')",
        [encoded],
      );
    }
  }
}
