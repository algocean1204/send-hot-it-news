import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/schedule_repository.dart';
import 'database_provider.dart';

// ============================================================
// F05: 스케줄 로그 Provider — 누락 실행 건수를 제공한다
// ============================================================

/// ScheduleRepository 인스턴스 Provider
final scheduleRepositoryProvider = Provider<AsyncValue<ScheduleRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => ScheduleRepository(db));
});

/// 누락된 실행 건수 — 홈 화면 경고 배너 표시 여부를 결정한다
final missedRunCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repoAsync = ref.watch(scheduleRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getMissedRunCount(),
    loading: () => Future.value(0),
    error: (e, _) => Future.value(0),
  );
});
