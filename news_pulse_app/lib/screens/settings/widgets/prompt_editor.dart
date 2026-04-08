import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/prompt_version.dart';
import 'settings_section_card.dart';
import 'prompt_type_tab.dart';

// ============================================================
// 프롬프트 편집기 위젯 (F13)
// 탭별로 summarize_ko / summarize_en / translate 프롬프트를 편집하고
// 버전 이력을 표시한다 — 탭 내용은 prompt_type_tab.dart에 분리되어 있다
// ============================================================

const _kPromptTypes = ['summarize_ko', 'summarize_en', 'translate'];

class PromptEditor extends ConsumerStatefulWidget {
  const PromptEditor({super.key});

  @override
  ConsumerState<PromptEditor> createState() => _PromptEditorState();
}

class _PromptEditorState extends ConsumerState<PromptEditor> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  // 각 탭의 TextEditingController를 개별 관리한다
  final _controllers = {for (final t in _kPromptTypes) t: TextEditingController()};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _kPromptTypes.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: '프롬프트 관리',
      description: '요약/번역 프롬프트를 편집하고 버전 이력을 관리한다',
      child: SizedBox(
        height: 340,
        child: Column(children: [
          // 탭바
          TabBar(
            controller: _tab,
            tabs: _kPromptTypes
                .map((t) => Tab(
                      text: PromptVersion(
                              id: 0, promptType: t, version: 0, content: '', isActive: false, createdAt: '')
                          .typeLabel,
                    ))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: _kPromptTypes.map((t) => PromptTypeTab(
                promptType: t,
                controller: _controllers[t]!,
              )).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}
