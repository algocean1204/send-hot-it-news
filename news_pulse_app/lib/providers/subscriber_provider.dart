import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscriber.dart';
import '../repositories/subscriber_repository.dart';
import 'database_provider.dart';

// ============================================================
// 구독자 관련 Provider — SubscriberRepository를 래핑한다
// ============================================================

/// SubscriberRepository 인스턴스 Provider
final subscriberRepositoryProvider = Provider<AsyncValue<SubscriberRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => SubscriberRepository(db));
});

/// 상태별 구독자 수 맵 (홈 화면 카드용)
final subscriberCountProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final repoAsync = ref.watch(subscriberRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getCountByStatus(),
    loading: () => Future.value({}),
    error: (e, _) => Future.value({}),
  );
});

/// 특정 상태의 구독자 목록
final subscribersByStatusProvider = FutureProvider.autoDispose
    .family<List<Subscriber>, SubscriberStatus>((ref, status) async {
  final repoAsync = ref.watch(subscriberRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getByStatus(status),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});

/// 검색어 상태 — 구독자 검색창에서 사용
final subscriberSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// 검색 결과 구독자 목록
final subscriberSearchResultProvider = FutureProvider.autoDispose<List<Subscriber>>(
  (ref) async {
    final query = ref.watch(subscriberSearchQueryProvider);
    if (query.isEmpty) return [];
    final repoAsync = ref.watch(subscriberRepositoryProvider);
    return repoAsync.when(
      data: (repo) => repo.search(query),
      loading: () => Future.value([]),
      error: (e, _) => Future.value([]),
    );
  },
);
