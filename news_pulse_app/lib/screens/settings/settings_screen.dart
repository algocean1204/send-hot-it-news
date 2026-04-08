import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/source_section.dart';
import 'widgets/filter_section.dart';
import 'widgets/keyword_chip_input.dart';
import 'widgets/digest_settings.dart';
import 'widgets/blacklist_suggestion_card.dart';
import 'widgets/threshold_suggestion.dart';
import 'widgets/prompt_editor.dart';
import 'widgets/token_management_section.dart';
import 'widgets/source_wizard_dialog.dart';

// ============================================================
// 화면 7: 설정 (Settings) — 얇은 조립 위젯
// 각 섹션 위젯을 나열하고, 데이터 로딩 상태만 관리한다
// 세부 로직은 각 섹션 위젯 파일에 위임한다
// ============================================================

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(configMapProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, ref),
            const SizedBox(height: 24),
            configsAsync.when(
              data: (configs) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SourceSection(configs: configs),
                  const SizedBox(height: 16),
                  FilterSection(configs: configs),
                  const SizedBox(height: 16),
                  DigestSettings(configs: configs),
                  const SizedBox(height: 16),
                  const KeywordChipInput(),
                  const SizedBox(height: 16),
                  const BlacklistSuggestionCard(),
                  const SizedBox(height: 16),
                  ThresholdSuggestion(currentConfigs: {
                    for (final e in configs.entries) e.key: e.value.value
                  }),
                  const SizedBox(height: 16),
                  const PromptEditor(),
                  const SizedBox(height: 16),
                  const TokenManagementSection(),
                ],
              ),
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('오류: $e', style: const TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('설정', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
            Text('소스·필터·프롬프트·토큰 관리', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        const Spacer(),
        // 소스 추가 위저드 버튼
        ElevatedButton.icon(
          onPressed: () => showSourceWizardDialog(context, ref),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('소스 추가', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => ref.invalidate(configMapProvider),
          icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          tooltip: '새로고침',
        ),
      ],
    );
  }
}
