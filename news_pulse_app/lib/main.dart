import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/menu_bar_service.dart';
import 'app.dart';

// ============================================================
// 앱 엔트리포인트 — macOS FFI 초기화 후 Riverpod ProviderScope를 최상위에 배치한다
// 메뉴바 서비스는 앱 시작 시 1회 초기화한다
// ============================================================

final _menuBarService = MenuBarService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // macOS에서 SQLite FFI를 초기화한다 — sqflite_common_ffi 필수 초기화 단계
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // tray_manager 초기화 — macOS 메뉴바 서비스에 필요하다
  await _menuBarService.initialize(
    onAction: _handleMenuBarAction,
  );

  runApp(
    // 모든 Provider가 이 ProviderScope 내에서 동작한다
    const ProviderScope(
      child: NewsPulseApp(),
    ),
  );
}

/// 메뉴바 항목 클릭 이벤트를 처리한다
void _handleMenuBarAction(String action) {
  switch (action) {
    case 'quit':
      // 앱을 안전하게 종료한다
      _menuBarService.dispose();
      break;
    case 'run_now':
      // F02 Manual Trigger와 연동 — 현재는 플레이스홀더다
      debugPrint('[MenuBar] 즉시 실행 요청');
      break;
    case 'open_app':
      // 메인 윈도우를 앞으로 가져온다 (tray_manager가 처리)
      debugPrint('[MenuBar] 앱 열기 요청');
      break;
  }
}
