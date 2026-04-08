import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'blacklist_suggestion_provider.dart' show analyticsRepositoryProvider;

// ============================================================
// 임계값 교정 Provider — 소스별 통과율을 분석해 최적 임계값 제안을 반환한다
// ============================================================

/// 소스별 통과율 + 제안 임계값 묶음
class CalibrationResult {
  final String source;
  final double passRate;
  final int totalCount;
  final int sentCount;
  /// 목표 통과율(30-50%)에 맞는 제안 임계값 (현재 값 기반 단순 휴리스틱)
  final String? suggestedThresholdKey;

  const CalibrationResult({
    required this.source,
    required this.passRate,
    required this.totalCount,
    required this.sentCount,
    this.suggestedThresholdKey,
  });
}

/// 교정 결과 목록 Provider
final calibrationProvider = FutureProvider.autoDispose<List<CalibrationResult>>((ref) async {
  final repoAsync = ref.watch(analyticsRepositoryProvider);
  return repoAsync.when(
    data: (repo) async {
      final rates = await repo.getPassRateBySource();
      return rates.map((r) {
        // 소스 이름으로 filter_config 키를 추정한다
        final key = _guessThresholdKey(r.source);
        return CalibrationResult(
          source: r.source,
          passRate: r.passRate,
          totalCount: r.totalCount,
          sentCount: r.sentCount,
          suggestedThresholdKey: key,
        );
      }).toList();
    },
    loading: () => Future.value([]),
    error: (e, _) => Future.value([]),
  );
});

/// 소스명으로 filter_config 키를 유추한다
String? _guessThresholdKey(String source) {
  final lower = source.toLowerCase();
  if (lower.contains('hacker') || lower == 'hn') return 'hn_min_points';
  if (lower.contains('reddit') && lower.contains('llama')) return 'reddit_localllama_min_upvotes';
  if (lower.contains('reddit') && lower.contains('claude')) return 'reddit_claudeai_min_upvotes';
  if (lower.contains('reddit') && lower.contains('cursor')) return 'reddit_cursor_min_upvotes';
  return null;
}
