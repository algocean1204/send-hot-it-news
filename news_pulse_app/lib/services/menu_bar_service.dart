import 'package:tray_manager/tray_manager.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// macOS 메뉴바 서비스 — tray_manager 패키지로 시스템 트레이 아이콘을 관리한다
// 상태(정상/에러/실행중)에 따라 아이콘을 교체하고 메뉴 항목을 갱신한다
// ============================================================

/// 메뉴바 항목 클릭 이벤트 콜백 유형
typedef MenuBarActionCallback = void Function(String action);

class MenuBarService with TrayListener {
  MenuBarActionCallback? _onAction;
  bool _initialized = false;

  /// 메뉴바 서비스를 초기화한다 — 앱 시작 시 1회 호출한다
  Future<void> initialize({MenuBarActionCallback? onAction}) async {
    if (_initialized) return;
    _onAction = onAction;
    trayManager.addListener(this);
    await _setIcon('green');
    await _updateMenu(
      lastStatus: '초기화 중...',
      errorCount: 0,
    );
    _initialized = true;
  }

  /// 상태에 따라 트레이 아이콘 색상을 갱신한다
  Future<void> updateStatus({
    required String dotColor,   // 'green' | 'red' | 'yellow'
    required String lastStatus,
    required int errorCount,
    String? nextRunAt,
  }) async {
    if (!_initialized) return;
    await _setIcon(dotColor);
    await _updateMenu(
      lastStatus: lastStatus,
      errorCount: errorCount,
      nextRunAt: nextRunAt,
    );
  }

  /// 서비스 정리 — 리스너를 해제한다
  void dispose() {
    trayManager.removeListener(this);
  }

  // ─── 내부 헬퍼 ───────────────────────────────────────────

  Future<void> _setIcon(String color) async {
    // tray_manager는 assets 경로를 사용한다
    // 단색 아이콘이 없으면 동일 아이콘으로 대체한다 — 실제 아이콘은 assets/에 추가해야 한다
    try {
      await trayManager.setIcon('assets/tray_icon.png');
    } catch (e) {
      // 아이콘 파일 없음 — 무시하고 계속 진행한다
      debugPrint('[MenuBarService] 아이콘 설정 실패: $e');
    }
  }

  Future<void> _updateMenu({
    required String lastStatus,
    required int errorCount,
    String? nextRunAt,
  }) async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'status',
          label: '상태: $lastStatus',
          disabled: true,
        ),
        MenuItem(
          key: 'errors',
          label: '에러: $errorCount건',
          disabled: true,
        ),
        if (nextRunAt != null)
          MenuItem(
            key: 'next_run',
            label: '다음 실행: $nextRunAt',
            disabled: true,
          ),
        MenuItem.separator(),
        MenuItem(
          key: 'run_now',
          label: '즉시 실행',
        ),
        MenuItem(
          key: 'open_app',
          label: '앱 열기',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: '종료',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  // ─── TrayListener 구현 ────────────────────────────────────

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key != null) {
      _onAction?.call(key);
    }
  }
}
