import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/processed_item.dart';
import '../models/hot_news.dart';
import '../repositories/news_repository.dart';
import 'database_provider.dart';

// ============================================================
// 뉴스 관련 Provider — NewsRepository를 래핑하여 상태를 관리한다
// ============================================================

/// NewsRepository 인스턴스 Provider
final newsRepositoryProvider = Provider<AsyncValue<NewsRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => NewsRepository(db));
});

/// 오늘 전송된 뉴스 건수
final todaySentCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repoAsync = ref.watch(newsRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getTodaySentCount(),
    loading: () => Future.value(0),
    error: (e, _) => Future.value(0),
  );
});

/// 날짜별 뉴스 목록 — 날짜 문자열(yyyy-MM-dd)을 인자로 받는다
final newsByDateProvider = FutureProvider.autoDispose.family<List<ProcessedItem>, String>(
  (ref, date) async {
    final repoAsync = ref.watch(newsRepositoryProvider);
    return repoAsync.when(
      data: (repo) => repo.getItemsByDate(date),
      loading: () => Future.value([]),
      error: (e, _) => Future.value([]),
    );
  },
);

/// 전체 핫뉴스 목록
final hotNewsProvider = FutureProvider.autoDispose<List<HotNews>>((ref) async {
  final repoAsync = ref.watch(newsRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getAllHotNews(),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});

/// 소스별/일별 뉴스 건수 (통계 화면용)
final sourceCountByDayProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final repoAsync = ref.watch(newsRepositoryProvider);
    return repoAsync.when(
      data: (repo) => repo.getSourceCountByDay(),
      loading: () => Future.value([]),
      error: (e, _) => Future.value([]),
    );
  },
);

/// 파이프라인 경로별 건수 (통계 화면용)
final pipelinePathCountProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final repoAsync = ref.watch(newsRepositoryProvider);
    return repoAsync.when(
      data: (repo) => repo.getPipelinePathCount(),
      loading: () => Future.value([]),
      error: (e, _) => Future.value([]),
    );
  },
);

/// F03: 읽지 않은 뉴스 건수 — 홈 화면 뱃지 및 카드에 표시한다
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repoAsync = ref.watch(newsRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getUnreadCount(),
    loading: () => Future.value(0),
    error: (e, _) => Future.value(0),
  );
});
