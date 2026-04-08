import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/prompt_version.dart';

// ============================================================
// 프롬프트 버전 데이터 접근 레이어 — prompt_versions 테이블 담당
// ============================================================

class PromptRepository {
  final Database _db;

  PromptRepository(this._db);

  /// 특정 유형의 모든 프롬프트 버전을 최신 순으로 조회한다
  Future<List<PromptVersion>> getAll(String promptType) async {
    final maps = await _db.rawQuery(
      'SELECT * FROM prompt_versions WHERE prompt_type = ? ORDER BY version DESC',
      [promptType],
    );
    return maps.map(PromptVersion.fromMap).toList();
  }

  /// 특정 유형의 현재 활성 프롬프트를 조회한다
  Future<PromptVersion?> getActive(String promptType) async {
    final maps = await _db.rawQuery(
      'SELECT * FROM prompt_versions WHERE prompt_type = ? AND is_active = 1 LIMIT 1',
      [promptType],
    );
    if (maps.isEmpty) return null;
    return PromptVersion.fromMap(maps.first);
  }

  /// 새 버전을 저장한다 — 기존 버전은 자동으로 다음 정수 버전 번호를 부여한다
  Future<void> createVersion(String promptType, String content) async {
    // 최대 버전 번호를 조회해 +1 한다
    final result = await _db.rawQuery(
      'SELECT MAX(version) AS max_v FROM prompt_versions WHERE prompt_type = ?',
      [promptType],
    );
    final maxV = (result.first['max_v'] as int?) ?? 0;
    final newVersion = maxV + 1;

    // 기존 활성 버전을 비활성화한다
    await _db.rawUpdate(
      'UPDATE prompt_versions SET is_active = 0 WHERE prompt_type = ?',
      [promptType],
    );

    // 새 버전을 활성 상태로 삽입한다
    await _db.rawInsert(
      'INSERT INTO prompt_versions (prompt_type, version, content, is_active) VALUES (?, ?, ?, 1)',
      [promptType, newVersion, content],
    );
  }

  /// 특정 버전을 활성 버전으로 지정한다
  Future<void> activate(int id, String promptType) async {
    // 동일 유형의 기존 활성을 해제한다
    await _db.rawUpdate(
      'UPDATE prompt_versions SET is_active = 0 WHERE prompt_type = ?',
      [promptType],
    );
    await _db.rawUpdate(
      'UPDATE prompt_versions SET is_active = 1 WHERE id = ?',
      [id],
    );
  }
}
