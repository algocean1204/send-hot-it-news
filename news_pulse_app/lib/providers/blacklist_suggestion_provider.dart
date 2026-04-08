import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/analytics_repository.dart';
import 'database_provider.dart';

// ============================================================
// 블랙리스트 제안 Provider — 필터링 패턴 분석 결과를 제공한다
// 무시한 단어 목록을 상태로 보관해 UI에서 제외한다
// ============================================================

/// AnalyticsRepository 인스턴스 Provider
final analyticsRepositoryProvider = Provider<AsyncValue<AnalyticsRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => AnalyticsRepository(db));
});

/// 블랙리스트 제안 단어 목록 Provider
final blacklistSuggestionProvider = FutureProvider.autoDispose<List<WordFrequency>>((ref) async {
  final repoAsync = ref.watch(analyticsRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getFilteredWordFrequency(topN: 20),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});

/// 무시된 단어 목록 상태 — 사용자가 "무시" 클릭 시 추가한다
final ignoredSuggestionsProvider = StateProvider<Set<String>>((ref) => {});
