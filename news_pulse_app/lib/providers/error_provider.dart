import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/error_log.dart';
import '../repositories/error_repository.dart';
import 'database_provider.dart';

// ============================================================
// 에러 로그 관련 Provider — ErrorRepository를 래핑한다
// ============================================================

/// ErrorRepository 인스턴스 Provider
final errorRepositoryProvider = Provider<AsyncValue<ErrorRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => ErrorRepository(db));
});

/// 최근 에러 목록 (홈 화면 카드용, 5건)
final recentErrorsProvider = FutureProvider.autoDispose<List<ErrorLog>>((ref) async {
  final repoAsync = ref.watch(errorRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getRecent(),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});

/// 심각도 필터 상태 — 에러 로그 화면에서 사용
final errorSeverityFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// 심각도 필터가 적용된 에러 로그 목록
final filteredErrorsProvider = FutureProvider.autoDispose<List<ErrorLog>>((ref) async {
  final severity = ref.watch(errorSeverityFilterProvider);
  final repoAsync = ref.watch(errorRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getFiltered(severity: severity),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});
