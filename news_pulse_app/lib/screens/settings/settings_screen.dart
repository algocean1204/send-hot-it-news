import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/config_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../repositories/config_repository.dart';
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
import 'widgets/settings_section_card.dart';

// ============================================================
// 화면 7: 설정 (Settings) — 얇은 조립 위젯
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
            _buildThemeToggle(ref),
            const SizedBox(height: 16),
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
              error: (e, _) => Text('오류: $e', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }

  /// 테마 모드 전환 섹션 — 라이트/다크 스위치
  Widget _buildThemeToggle(WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    return SettingsSectionCard(
      title: '테마',
      description: '앱 테마를 선택한다',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Text('라이트', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 12),
          Switch(
            value: isDark,
            onChanged: (value) async {
              ref.read(themeProvider.notifier).setMode(value ? ThemeMode.dark : ThemeMode.light);
              final dbAsync = ref.read(databaseProvider);
              dbAsync.whenData((db) async {
                await ConfigRepository(db).upsert('theme_mode', value ? 'dark' : 'light');
              });
            },
          ),
          const SizedBox(width: 12),
          Text('다크', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('설정', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600,
        )),
        Text('소스·필터·프롬프트·토큰 관리', style: TextStyle(
          color: AppColors.textSecondary, fontSize: 13,
        )),
      ]),
      const Spacer(),
      ElevatedButton.icon(
        onPressed: () => showSourceWizardDialog(context, ref),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('소스 추가', style: TextStyle(fontSize: 13)),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: () => ref.invalidate(configMapProvider),
        icon: Icon(Icons.refresh, color: AppColors.textSecondary),
        tooltip: '새로고침',
      ),
    ]);
  }
}
