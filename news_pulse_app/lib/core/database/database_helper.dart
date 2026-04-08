import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants.dart';

// ============================================================
// SQLite 연결 관리 — WAL 모드로 Python 백엔드와 동시 접근 가능하게 한다
// ============================================================

class DatabaseHelper {
  static Database? _database;

  /// 데이터베이스 인스턴스를 반환한다 (싱글톤 패턴)
  static Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// DB를 초기화하고 WAL 모드를 설정한다
  /// sqfliteFfiInit()는 main.dart에서 이미 호출하므로 여기서 중복 호출하지 않는다
  static Future<Database> _initDatabase() async {
    // 환경변수로 경로를 덮어쓸 수 있도록 지원
    final dbPath = Platform.environment['NEWS_PULSE_DB_PATH'] ?? kDefaultDbPath;

    // DB 파일이 있는 디렉토리가 없으면 미리 생성한다
    final dir = Directory(dbPath).parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onOpen: (db) async {
          // WAL 모드에서 Python 프로세스와 안전하게 동시 접근하기 위한 PRAGMA 설정
          // Python 백엔드가 이미 WAL/FK를 설정하므로 재확인 용도
          await db.execute('PRAGMA journal_mode=WAL');
          await db.execute('PRAGMA busy_timeout=5000');
          await db.execute('PRAGMA foreign_keys=ON');
          await db.execute('PRAGMA synchronous=NORMAL');
        },
      ),
    );

    return db;
  }

  /// DB 연결을 명시적으로 닫는다 (앱 종료 시 호출)
  static Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
