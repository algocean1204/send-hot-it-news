import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/run_history.dart';
import '../repositories/run_repository.dart';
import 'database_provider.dart';

// ============================================================
// 실행 이력 관련 Provider — RunRepository를 래핑한다
// ============================================================

/// RunRepository 인스턴스 Provider
final runRepositoryProvider = Provider<AsyncValue<RunRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => RunRepository(db));
});

/// 마지막 실행 기록 (홈 화면 봇 상태 카드용)
final latestRunProvider = FutureProvider.autoDispose<RunHistory?>((ref) async {
  final repoAsync = ref.watch(runRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getLatest(),
    loading: () => Future.value(null),
    error: (e, _) => Future.value(null),
  );
});

/// 최근 실행 이력 목록 (실행 이력 화면용)
final recentRunsProvider = FutureProvider.autoDispose<List<RunHistory>>((ref) async {
  final repoAsync = ref.watch(runRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getRecent(),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});

/// 통계 차트용 실행 이력
final statsRunsProvider = FutureProvider.autoDispose<List<RunHistory>>((ref) async {
  final repoAsync = ref.watch(runRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getForStats(),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});
