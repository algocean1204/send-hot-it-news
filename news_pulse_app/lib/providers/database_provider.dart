import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/database/database_helper.dart';

// ============================================================
// DB 인스턴스 Provider — 모든 Repository Provider가 이를 의존한다
// FutureProvider로 비동기 초기화를 처리한다
// ============================================================

final databaseProvider = FutureProvider<Database>((ref) async {
  final db = await DatabaseHelper.database;

  // 앱 종료 시 DB 연결을 정리한다
  ref.onDispose(() async {
    await DatabaseHelper.close();
  });

  return db;
});
