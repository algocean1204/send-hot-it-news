import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/filter_config.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/config_repository.dart';
import '../../../core/theme/app_theme.dart';
import 'threshold_slider.dart';
import 'settings_section_card.dart';

// ============================================================
// 필터 임계값 섹션 위젯 — HN·Reddit 업보트 기준 및 실행 설정을 담는다
// settings_screen.dart에서 분리한다
// ============================================================

class FilterSection extends ConsumerWidget {
  final Map<String, FilterConfig> configs;

  const FilterSection({super.key, required this.configs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SettingsSectionCard(
          title: 'Hacker News 필터',
          description: 'HN 업보트 최소 기준',
          child: _buildHnSliders(context, ref),
        ),
        const SizedBox(height: 16),
        SettingsSectionCard(
          title: 'Reddit 필터',
          description: '각 서브레딧 업보트 최소 기준',
          child: _buildRedditSliders(context, ref),
        ),
        const SizedBox(height: 16),
        SettingsSectionCard(
          title: '실행 설정',
          description: '파이프라인 실행 파라미터',
          child: _buildRunSettings(context, ref),
        ),
      ],
    );
  }

  Widget _buildHnSliders(BuildContext context, WidgetRef ref) {
    return Column(children: [
      if (configs.containsKey('hn_min_points'))
        ThresholdSlider(
            config: configs['hn_min_points']!, min: 0, max: 500, divisions: 50,
            onChanged: (v) => _update(context, ref, 'hn_min_points', v)),
      if (configs.containsKey('hn_young_min_points'))
        ThresholdSlider(
            config: configs['hn_young_min_points']!, min: 0, max: 200, divisions: 40,
            onChanged: (v) => _update(context, ref, 'hn_young_min_points', v)),
    ]);
  }

  Widget _buildRedditSliders(BuildContext context, WidgetRef ref) {
    return Column(children: [
      if (configs.containsKey('reddit_localllama_min_upvotes'))
        ThresholdSlider(
            config: configs['reddit_localllama_min_upvotes']!, min: 0, max: 200, divisions: 40,
            onChanged: (v) => _update(context, ref, 'reddit_localllama_min_upvotes', v)),
      if (configs.containsKey('reddit_claudeai_min_upvotes'))
        ThresholdSlider(
            config: configs['reddit_claudeai_min_upvotes']!, min: 0, max: 200, divisions: 40,
            onChanged: (v) => _update(context, ref, 'reddit_claudeai_min_upvotes', v)),
      if (configs.containsKey('reddit_cursor_min_upvotes'))
        ThresholdSlider(
            config: configs['reddit_cursor_min_upvotes']!, min: 0, max: 200, divisions: 40,
            onChanged: (v) => _update(context, ref, 'reddit_cursor_min_upvotes', v)),
    ]);
  }

  Widget _buildRunSettings(BuildContext context, WidgetRef ref) {
    return Column(children: [
      if (configs.containsKey('max_items_per_run'))
        ThresholdSlider(
            config: configs['max_items_per_run']!, min: 1, max: 20, divisions: 19,
            onChanged: (v) => _update(context, ref, 'max_items_per_run', v)),
      if (configs.containsKey('allow_tier1_overflow'))
        _buildSwitchTile(context, ref, configs['allow_tier1_overflow']!),
    ]);
  }

  Widget _buildSwitchTile(BuildContext context, WidgetRef ref, FilterConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ALLOW TIER1 OVERFLOW',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          if (config.description != null)
            Text(config.description!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        Switch(
          value: config.boolValue,
          onChanged: (val) => _update(context, ref, 'allow_tier1_overflow', val ? '1' : '0'),
        ),
      ]),
    );
  }

  Future<void> _update(BuildContext context, WidgetRef ref, String key, String value) async {
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        await ConfigRepository(db).updateValue(key, value);
        ref.invalidate(configMapProvider);
        ref.invalidate(allConfigsProvider);
      },
      loading: () async {},
      error: (e, _) async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 실패: $e', style: const TextStyle(color: AppColors.textPrimary))),
          );
        }
      },
    );
  }
}
