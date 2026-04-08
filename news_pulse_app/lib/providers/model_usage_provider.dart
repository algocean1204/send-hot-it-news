import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/model_usage.dart';
import '../repositories/model_usage_repository.dart';
import 'database_provider.dart';

// ============================================================
// F06: 모델 사용량 Provider — 지연 추이 차트 데이터를 제공한다
// ============================================================

/// ModelUsageRepository 인스턴스 Provider
final modelUsageRepositoryProvider =
    Provider<AsyncValue<ModelUsageRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => ModelUsageRepository(db));
});

/// 날짜별 모델 평균 지연 추이 — 통계 화면 차트에 표시한다
final latencyTrendingProvider =
    FutureProvider.autoDispose<List<ModelLatencyPoint>>((ref) async {
  final repoAsync = ref.watch(modelUsageRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getLatencyTrending(days: 7),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});
