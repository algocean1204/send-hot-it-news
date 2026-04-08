import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';

// ============================================================
// 메뉴바 상태 Provider — DB를 30초마다 폴링해 현재 상태를 갱신한다
// ============================================================

/// 메뉴바에 표시할 상태 정보
class MenuBarStatus {
  final String? lastRunStatus;   // 'success' | 'failure' | 'running' | null
  final String? lastRunAt;       // 마지막 실행 시각 (ISO8601)
  final int errorCount;          // 최근 미해결 에러 건수
  final String? nextRunAt;       // 다음 예정 실행 시각 (launchd 기준 추정)

  const MenuBarStatus({
    this.lastRunStatus,
    this.lastRunAt,
    this.errorCount = 0,
    this.nextRunAt,
  });

  /// 아이콘 색상 구분에 사용한다 — 에러 있음=red, 실행중=yellow, 정상=green
  String get dotColor {
    if (lastRunStatus == 'failure') return 'red';
    if (lastRunStatus == 'running') return 'yellow';
    return 'green';
  }
}

/// 메뉴바 상태 AsyncNotifier — 30초 주기로 DB를 조회한다
class MenuBarNotifier extends AsyncNotifier<MenuBarStatus> {
  Timer? _timer;

  @override
  Future<MenuBarStatus> build() async {
    // Notifier가 dispose될 때 타이머를 정리한다
    ref.onDispose(() => _timer?.cancel());
    _startPolling();
    return _fetchStatus();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(_fetchStatus);
    });
  }

  Future<MenuBarStatus> _fetchStatus() async {
    final dbAsync = await ref.read(databaseProvider.future);

    // 마지막 실행 기록 조회
    final runRows = await dbAsync.rawQuery(
      "SELECT status, started_at FROM run_history ORDER BY started_at DESC LIMIT 1",
    );
    final lastStatus = runRows.isNotEmpty ? runRows.first['status'] as String? : null;
    final lastAt = runRows.isNotEmpty ? runRows.first['started_at'] as String? : null;

    // 미해결 에러 건수 조회 (최근 24시간)
    final errRows = await dbAsync.rawQuery(
      "SELECT COUNT(*) AS c FROM error_log "
      "WHERE created_at >= datetime('now', '-1 day', 'localtime')",
    );
    final errorCount = (errRows.first['c'] as int?) ?? 0;

    return MenuBarStatus(
      lastRunStatus: lastStatus,
      lastRunAt: lastAt,
      errorCount: errorCount,
    );
  }

  /// 외부에서 상태를 즉시 갱신한다 (수동 실행 후 호출)
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchStatus);
  }
}

/// 메뉴바 상태 Provider
final menuBarProvider = AsyncNotifierProvider<MenuBarNotifier, MenuBarStatus>(
  MenuBarNotifier.new,
);
