import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/whitelist_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/whitelist_repository.dart';
import 'settings_section_card.dart';

// ============================================================
// 키워드 화이트리스트 입력 위젯 (F01)
// Chip으로 키워드를 표시하고, TextField + 추가 버튼으로 새 키워드를 등록한다
// 소문자 정규화는 Repository에서 수행한다
// ============================================================

class KeywordChipInput extends ConsumerStatefulWidget {
  const KeywordChipInput({super.key});

  @override
  ConsumerState<KeywordChipInput> createState() => _KeywordChipInputState();
}

class _KeywordChipInputState extends ConsumerState<KeywordChipInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keywordsAsync = ref.watch(whitelistKeywordsProvider);

    return SettingsSectionCard(
      title: '관심 키워드',
      description: 'Tier3 아이템이 키워드 포함 시 업보트 무관하게 통과한다',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 등록된 키워드 Chip 목록
            keywordsAsync.when(
              data: (keywords) => keywords.isEmpty
                  ? const Text('등록된 키워드가 없습니다',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: keywords
                          .map((kw) => Chip(
                                label: Text(kw.keyword,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary, fontSize: 12)),
                                backgroundColor: AppColors.surfaceSecondary,
                                side: const BorderSide(color: AppColors.border),
                                deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                                onDeleted: () => _delete(kw.id),
                              ))
                          .toList(),
                    ),
              loading: () => const SizedBox(
                  height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (e, _) => Text('오류: $e', style: const TextStyle(color: AppColors.error)),
            ),
            const SizedBox(height: 12),
            // 키워드 입력 Row
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: '키워드 입력 (예: llm, claude)',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _add, child: const Text('추가')),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        await WhitelistRepository(db).add(text);
        _controller.clear();
        ref.invalidate(whitelistKeywordsProvider);
      },
      loading: () async {},
      error: (e, _) async {},
    );
  }

  Future<void> _delete(int id) async {
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        await WhitelistRepository(db).delete(id);
        ref.invalidate(whitelistKeywordsProvider);
      },
      loading: () async {},
      error: (e, _) async {},
    );
  }
}
