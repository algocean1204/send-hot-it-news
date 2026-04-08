import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/filter_config.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/config_repository.dart';
import '../../../core/theme/app_theme.dart';
import 'source_toggle_tile.dart';
import 'settings_section_card.dart';

// ============================================================
// 뉴스 소스 활성화 섹션 위젯 — settings_screen.dart에서 분리한다
// source_X_enabled 키를 가진 설정들을 스위치 타일로 표시한다
// ============================================================

class SourceSection extends ConsumerWidget {
  final Map<String, FilterConfig> configs;

  const SourceSection({super.key, required this.configs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      title: '뉴스 소스 활성화',
      description: '각 소스의 뉴스 수집 여부를 설정한다',
      child: Column(
        children: configs.entries
            .where((e) => e.key.startsWith('source_') && e.key.endsWith('_enabled'))
            .map((e) => SourceToggleTile(
                  config: e.value,
                  onChanged: (val) => _update(context, ref, e.key, val ? '1' : '0'),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _update(BuildContext context, WidgetRef ref, String key, String value) async {
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        await ConfigRepository(db).updateValue(key, value);
        ref.invalidate(configMapProvider);
      },
      loading: () async {},
      error: (e, _) async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 실패: $e', style: TextStyle(color: AppColors.textPrimary))),
          );
        }
      },
    );
  }
}
