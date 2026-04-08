import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/blacklist_suggestion_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/config_repository.dart';
import 'settings_section_card.dart';

// ============================================================
// 블랙리스트 제안 카드 위젯 (F08)
// 필터링 패턴을 분석해 자주 등장하는 단어를 제안한다
// "추가" 클릭 시 filter_config의 blacklist_keywords에 반영한다
// "무시" 클릭 시 세션 내에서 해당 단어를 제안 목록에서 제외한다
// ============================================================

class BlacklistSuggestionCard extends ConsumerWidget {
  const BlacklistSuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(blacklistSuggestionProvider);
    final ignored = ref.watch(ignoredSuggestionsProvider);

    return SettingsSectionCard(
      title: '블랙리스트 제안',
      description: '자주 필터링된 단어 — 블랙리스트에 추가하면 해당 아이템을 건너뜁니다',
      child: suggestionsAsync.when(
        data: (suggestions) {
          final visible = suggestions.where((s) => !ignored.contains(s.word)).toList();
          if (visible.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('제안 단어가 없습니다 (수집 데이터 부족)',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            );
          }
          return Column(
            children: visible.take(10).map((wf) => _buildRow(context, ref, wf)).toList(),
          );
        },
        loading: () => const SizedBox(
            height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('분석 오류: $e', style: const TextStyle(color: AppColors.error, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, WidgetRef ref, dynamic wf) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(wf.word,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            Text('${wf.count}회 등장',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
        TextButton(
          onPressed: () => _addToBlacklist(context, ref, wf.word),
          child: const Text('추가', style: TextStyle(color: AppColors.accent, fontSize: 12)),
        ),
        TextButton(
          onPressed: () {
            ref.read(ignoredSuggestionsProvider.notifier).update((s) => {...s, wf.word});
          },
          child: const Text('무시', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      ]),
    );
  }

  Future<void> _addToBlacklist(BuildContext context, WidgetRef ref, String word) async {
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        final repo = ConfigRepository(db);
        final map = await repo.getAllAsMap();
        final existing = map['blacklist_keywords']?.value ?? '';
        // 쉼표 구분 문자열에 단어를 추가한다
        final newVal = existing.isEmpty ? word : '$existing,$word';
        await repo.updateValue('blacklist_keywords', newVal);
        ref.invalidate(configMapProvider);
        // 제안 목록에서 무시 처리한다
        ref.read(ignoredSuggestionsProvider.notifier).update((s) => {...s, word});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$word"을 블랙리스트에 추가했습니다',
                style: const TextStyle(color: AppColors.textPrimary))),
          );
        }
      },
      loading: () async {},
      error: (e, _) async {},
    );
  }
}
