import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import '../repositories/config_repository.dart';

// ============================================================
// 테마 모드 Provider — 라이트/다크 전환 상태를 관리한다
// DB에서 저장된 테마 설정을 로드하고, 변경 시 반영한다
// ============================================================

/// 테마 모드를 관리하는 StateNotifier — 기본값은 라이트 모드
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light);

  /// 라이트 ↔ 다크를 토글한다
  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  /// 특정 모드로 직접 설정한다
  void setMode(ThemeMode mode) => state = mode;
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final notifier = ThemeNotifier();
  // DB가 준비되면 저장된 테마 설정을 로드한다
  ref.listen(databaseProvider, (prev, next) {
    next.whenData((db) async {
      final repo = ConfigRepository(db);
      final configs = await repo.getAllAsMap();
      final saved = configs['theme_mode']?.value;
      if (saved == 'dark') {
        notifier.setMode(ThemeMode.dark);
      }
    });
  }, fireImmediately: true);
  return notifier;
});
