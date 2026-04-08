import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/whitelist_keyword.dart';
import '../repositories/whitelist_repository.dart';
import 'database_provider.dart';

// ============================================================
// 화이트리스트 관련 Provider — WhitelistRepository를 래핑한다
// ============================================================

/// WhitelistRepository 인스턴스 Provider
final whitelistRepositoryProvider = Provider<AsyncValue<WhitelistRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => WhitelistRepository(db));
});

/// 전체 화이트리스트 키워드 목록 — 설정 화면 Chip 표시에 사용한다
final whitelistKeywordsProvider = FutureProvider.autoDispose<List<WhitelistKeyword>>((ref) async {
  final repoAsync = ref.watch(whitelistRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getAll(),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});
