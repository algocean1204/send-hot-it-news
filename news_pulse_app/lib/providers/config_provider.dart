import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/filter_config.dart';
import '../repositories/config_repository.dart';
import 'database_provider.dart';

// ============================================================
// 설정 관련 Provider — ConfigRepository를 래핑한다
// ============================================================

/// ConfigRepository 인스턴스 Provider
final configRepositoryProvider = Provider<AsyncValue<ConfigRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => ConfigRepository(db));
});

/// 모든 설정 목록
final allConfigsProvider = FutureProvider.autoDispose<List<FilterConfig>>((ref) async {
  final repoAsync = ref.watch(configRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getAll(),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});

/// 설정 맵 (key -> FilterConfig) — 빠른 조회를 위해 맵 형태로 제공
final configMapProvider = FutureProvider.autoDispose<Map<String, FilterConfig>>((ref) async {
  final repoAsync = ref.watch(configRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getAllAsMap(),
    loading: () => Future.value({}),
    error: (e, _) => Future.value({}),
  );
});
