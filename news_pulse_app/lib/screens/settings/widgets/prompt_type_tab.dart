import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/prompt_version.dart';
import '../../../providers/prompt_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/prompt_repository.dart';

// 단일 프롬프트 유형 탭 내용 (F13) — prompt_editor.dart에서 분리

class PromptTypeTab extends ConsumerStatefulWidget {
  final String promptType;
  final TextEditingController controller;

  const PromptTypeTab({super.key, required this.promptType, required this.controller});

  @override
  ConsumerState<PromptTypeTab> createState() => _PromptTypeTabState();
}

class _PromptTypeTabState extends ConsumerState<PromptTypeTab> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activePromptProvider(widget.promptType));
    final versionsAsync = ref.watch(promptVersionsProvider(widget.promptType));

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 현재 활성 프롬프트 표시/편집 영역
        activeAsync.when(
          data: (active) {
            // 처음 로드 시 컨트롤러를 초기화한다
            if (!_editMode && active != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.controller.text.isEmpty) {
                  widget.controller.text = active.content;
                }
              });
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(active != null ? 'v${active.version} (활성)' : '버전 없음',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const Spacer(),
                if (!_editMode)
                  TextButton(
                    onPressed: () => setState(() => _editMode = true),
                    child: const Text('편집', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                  ),
              ]),
              const SizedBox(height: 4),
              TextField(
                controller: widget.controller,
                enabled: _editMode,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(isDense: true),
              ),
              if (_editMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    ElevatedButton(
                      onPressed: () => _saveVersion(context),
                      child: const Text('새 버전 저장', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _editMode = false),
                      child: const Text('취소', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                  ]),
                ),
            ]);
          },
          loading: () => const SizedBox(height: 32, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => Text('오류: $e', style: const TextStyle(color: AppColors.error, fontSize: 11)),
        ),
        const SizedBox(height: 8),
        const Divider(color: AppColors.border),
        // 버전 이력 목록
        Expanded(
          child: versionsAsync.when(
            data: (versions) => ListView.builder(
              itemCount: versions.length,
              itemBuilder: (_, i) {
                final v = versions[i];
                return ListTile(
                  dense: true,
                  title: Text('v${v.version}',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                  subtitle: Text(v.createdAt,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  trailing: v.isActive
                      ? const Text('활성', style: TextStyle(color: AppColors.success, fontSize: 11))
                      : TextButton(
                          onPressed: () => _activate(context, v),
                          child: const Text('활성화', style: TextStyle(color: AppColors.accent, fontSize: 11)),
                        ),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Text('오류: $e', style: const TextStyle(color: AppColors.error, fontSize: 11)),
          ),
        ),
      ]),
    );
  }

  Future<void> _saveVersion(BuildContext context) async {
    final content = widget.controller.text.trim();
    if (content.isEmpty) return;
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        await PromptRepository(db).createVersion(widget.promptType, content);
        ref.invalidate(promptVersionsProvider(widget.promptType));
        ref.invalidate(activePromptProvider(widget.promptType));
        setState(() => _editMode = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('새 버전이 저장되고 활성화되었습니다',
                style: TextStyle(color: AppColors.textPrimary))),
          );
        }
      },
      loading: () async {},
      error: (e, _) async {},
    );
  }

  /// 선택한 버전을 활성화하고 편집기 내용을 갱신한다
  Future<void> _activate(BuildContext context, PromptVersion v) async {
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        await PromptRepository(db).activate(v.id, widget.promptType);
        ref.invalidate(promptVersionsProvider(widget.promptType));
        ref.invalidate(activePromptProvider(widget.promptType));
        widget.controller.text = v.content;
      },
      loading: () async {},
      error: (e, _) async {},
    );
  }
}
