@TestOn('mac-os')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:news_pulse_app/repositories/news_repository.dart';

// ============================================================
// NewsRepository 단위 테스트 — 인메모리 SQLite DB를 사용한다
// macOS 전용 앱이므로 mac-os 태그를 붙여 VM 컴파일러 문제를 회피한다
// ============================================================

void main() {
  late Database db;
  late NewsRepository repo;

  setUpAll(() {
    // 테스트 환경에서 FFI 초기화
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // 테스트마다 새 인메모리 DB를 생성한다
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // 테이블 생성
          await db.execute('''
            CREATE TABLE processed_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              url_hash TEXT UNIQUE NOT NULL,
              url TEXT NOT NULL,
              title TEXT NOT NULL,
              source TEXT NOT NULL,
              language TEXT NOT NULL DEFAULT 'en',
              raw_content TEXT,
              summary_ko TEXT,
              tags TEXT,
              upvotes INTEGER DEFAULT 0,
              is_hot INTEGER DEFAULT 0,
              pipeline_path TEXT,
              processing_time_ms INTEGER,
              telegram_sent INTEGER DEFAULT 0,
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
            )
          ''');
          await db.execute('''
            CREATE TABLE hot_news (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              processed_item_id INTEGER NOT NULL,
              url TEXT NOT NULL,
              title TEXT NOT NULL,
              source TEXT NOT NULL,
              summary_ko TEXT NOT NULL,
              tags TEXT,
              upvotes INTEGER DEFAULT 0,
              hot_reason TEXT NOT NULL,
              created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
            )
          ''');
        },
      ),
    );
    repo = NewsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('오늘 전송 건수 조회', () {
    test('전송된 뉴스가 없으면 0을 반환한다', () async {
      final count = await repo.getTodaySentCount();
      expect(count, 0);
    });

    test('오늘 전송된 뉴스 건수를 정확히 반환한다', () async {
      // 오늘 날짜로 telegram_sent=1인 뉴스 2건 삽입
      await db.rawInsert(
        "INSERT INTO processed_items (url_hash, url, title, source, language, telegram_sent, created_at) "
        "VALUES ('h1', 'http://a.com', 'A', 'test', 'en', 1, datetime('now','localtime'))",
      );
      await db.rawInsert(
        "INSERT INTO processed_items (url_hash, url, title, source, language, telegram_sent, created_at) "
        "VALUES ('h2', 'http://b.com', 'B', 'test', 'en', 1, datetime('now','localtime'))",
      );
      // telegram_sent=0인 뉴스 1건 삽입 (카운트에 포함되면 안 됨)
      await db.rawInsert(
        "INSERT INTO processed_items (url_hash, url, title, source, language, telegram_sent, created_at) "
        "VALUES ('h3', 'http://c.com', 'C', 'test', 'en', 0, datetime('now','localtime'))",
      );

      final count = await repo.getTodaySentCount();
      expect(count, 2);
    });
  });

  group('날짜별 뉴스 조회', () {
    test('특정 날짜의 뉴스만 반환한다', () async {
      await db.rawInsert(
        "INSERT INTO processed_items (url_hash, url, title, source, language, created_at) "
        "VALUES ('h1', 'http://a.com', 'A', 'test', 'en', '2025-01-15 10:00:00')",
      );
      await db.rawInsert(
        "INSERT INTO processed_items (url_hash, url, title, source, language, created_at) "
        "VALUES ('h2', 'http://b.com', 'B', 'test', 'en', '2025-01-16 10:00:00')",
      );

      final items = await repo.getItemsByDate('2025-01-15');
      expect(items.length, 1);
      expect(items.first.title, 'A');
    });
  });

  group('핫뉴스 토글', () {
    test('markAsHot으로 is_hot=1이 되고 hot_news에 삽입된다', () async {
      await db.rawInsert(
        "INSERT INTO processed_items (url_hash, url, title, source, language, summary_ko, is_hot, created_at) "
        "VALUES ('h1', 'http://a.com', 'Test', 'test', 'en', '테스트 요약', 0, datetime('now','localtime'))",
      );

      final items = await repo.getItemsByDate(
        DateTime.now().toString().substring(0, 10),
      );
      expect(items.isNotEmpty, true);

      await repo.markAsHot(items.first);

      // is_hot이 1로 변경되었는지 확인
      final updated = await db.rawQuery(
        "SELECT is_hot FROM processed_items WHERE id=?",
        [items.first.id],
      );
      expect(updated.first['is_hot'], 1);

      // hot_news에 삽입되었는지 확인
      final hotNews = await db.rawQuery("SELECT * FROM hot_news");
      expect(hotNews.length, 1);
      expect(hotNews.first['hot_reason'], 'manual');
    });

    test('unmarkAsHot으로 is_hot=0이 되고 hot_news에서 삭제된다', () async {
      await db.rawInsert(
        "INSERT INTO processed_items (url_hash, url, title, source, language, summary_ko, is_hot, created_at) "
        "VALUES ('h1', 'http://a.com', 'Test', 'test', 'en', '요약', 1, datetime('now','localtime'))",
      );
      final id = (await db.rawQuery("SELECT id FROM processed_items LIMIT 1")).first['id'] as int;
      await db.rawInsert(
        "INSERT INTO hot_news (processed_item_id, url, title, source, summary_ko, hot_reason, created_at) "
        "VALUES ($id, 'http://a.com', 'Test', 'test', '요약', 'manual', datetime('now','localtime'))",
      );

      await repo.unmarkAsHot(id);

      final updated = await db.rawQuery(
        "SELECT is_hot FROM processed_items WHERE id=?",
        [id],
      );
      expect(updated.first['is_hot'], 0);

      final hotNews = await db.rawQuery("SELECT * FROM hot_news");
      expect(hotNews.isEmpty, true);
    });
  });
}
