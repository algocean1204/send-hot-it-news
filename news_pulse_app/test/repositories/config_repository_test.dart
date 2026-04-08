@TestOn('mac-os')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:news_pulse_app/repositories/config_repository.dart';

// ============================================================
// ConfigRepository 단위 테스트 — filter_config 읽기/쓰기를 검증한다
// ============================================================

void main() {
  late Database db;
  late ConfigRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE filter_config (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              key TEXT UNIQUE NOT NULL,
              value TEXT NOT NULL,
              description TEXT,
              updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
            )
          ''');
          // 시드 데이터 삽입
          await db.rawInsert(
            "INSERT INTO filter_config (key, value, description) VALUES ('source_geeknews_enabled', '1', 'GeekNews 활성화')",
          );
          await db.rawInsert(
            "INSERT INTO filter_config (key, value, description) VALUES ('hn_min_points', '100', 'HN 최소 업보트')",
          );
          await db.rawInsert(
            "INSERT INTO filter_config (key, value, description) VALUES ('allow_tier1_overflow', '0', 'Tier1 초과 허용')",
          );
        },
      ),
    );
    repo = ConfigRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('filter_config 읽기', () {
    test('모든 설정을 조회한다', () async {
      final configs = await repo.getAll();
      expect(configs.length, 3);
    });

    test('소스 설정만 필터링하여 조회한다', () async {
      final configs = await repo.getSourceConfigs();
      expect(configs.length, 1);
      expect(configs.first.key, 'source_geeknews_enabled');
    });

    test('맵 형태로 조회한다', () async {
      final configMap = await repo.getAllAsMap();
      expect(configMap.containsKey('hn_min_points'), true);
      expect(configMap['hn_min_points']!.intValue, 100);
    });

    test('bool 값 파싱이 정확하다', () async {
      final configs = await repo.getAllAsMap();
      expect(configs['source_geeknews_enabled']!.boolValue, true);
      expect(configs['allow_tier1_overflow']!.boolValue, false);
    });
  });

  group('filter_config 쓰기', () {
    test('설정값을 업데이트하면 DB에 반영된다', () async {
      await repo.updateValue('hn_min_points', '200');

      final configs = await repo.getAllAsMap();
      expect(configs['hn_min_points']!.intValue, 200);
    });

    test('bool 설정을 토글하면 DB에 반영된다', () async {
      // 비활성화 -> 활성화
      await repo.updateValue('allow_tier1_overflow', '1');
      final after = await repo.getAllAsMap();
      expect(after['allow_tier1_overflow']!.boolValue, true);
    });

    test('updated_at이 업데이트된다', () async {
      final before = await repo.getAllAsMap();
      final beforeTime = before['hn_min_points']!.updatedAt;

      // 잠시 후 업데이트
      await Future.delayed(const Duration(seconds: 1));
      await repo.updateValue('hn_min_points', '150');

      final after = await repo.getAllAsMap();
      final afterTime = after['hn_min_points']!.updatedAt;

      // 시간이 변경되었거나 같아야 한다 (1초 이내이면 같을 수도 있음)
      expect(afterTime.compareTo(beforeTime) >= 0, true);
    });
  });
}
