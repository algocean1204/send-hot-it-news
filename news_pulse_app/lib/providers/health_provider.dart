import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_check_result.dart';
import '../repositories/health_repository.dart';
import 'database_provider.dart';

// ============================================================
// 헬스체크 관련 Provider — HealthRepository를 래핑한다
// ============================================================

/// HealthRepository 인스턴스 Provider
final healthRepositoryProvider = Provider<AsyncValue<HealthRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => HealthRepository(db));
});

/// 최신 헬스체크 결과 목록 (check_type별 가장 최근)
final latestHealthResultsProvider = FutureProvider.autoDispose<List<HealthCheckResult>>(
  (ref) async {
    final repoAsync = ref.watch(healthRepositoryProvider);
    return repoAsync.when(
      data: (repo) => repo.getLatestResults(),
      loading: () => Future.value([]),
      error: (e, _) => Future.value([]),
    );
  },
);

/// 헬스체크 실행 중 상태 — 버튼 비활성화에 사용
final healthCheckRunningProvider = StateProvider.autoDispose<bool>((ref) => false);

/// 마지막 헬스체크 실행 결과 메시지
final healthCheckMessageProvider = StateProvider.autoDispose<String?>((ref) => null);
