import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prompt_version.dart';
import '../repositories/prompt_repository.dart';
import 'database_provider.dart';

// ============================================================
// 프롬프트 버전 관련 Provider — PromptRepository를 래핑한다
// ============================================================

/// PromptRepository 인스턴스 Provider
final promptRepositoryProvider = Provider<AsyncValue<PromptRepository>>((ref) {
  final dbAsync = ref.watch(databaseProvider);
  return dbAsync.whenData((db) => PromptRepository(db));
});

/// 특정 유형의 프롬프트 버전 목록 Provider — 탭별로 패밀리를 사용한다
final promptVersionsProvider = FutureProvider.autoDispose.family<List<PromptVersion>, String>((ref, promptType) async {
  final repoAsync = ref.watch(promptRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getAll(promptType),
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});

/// 특정 유형의 활성 프롬프트 Provider
final activePromptProvider = FutureProvider.autoDispose.family<PromptVersion?, String>((ref, promptType) async {
  final repoAsync = ref.watch(promptRepositoryProvider);
  return repoAsync.when(
    data: (repo) => repo.getActive(promptType),
    loading: () => Future.value(null),
    error: (e, _) => Future.value(null),
  );
});
