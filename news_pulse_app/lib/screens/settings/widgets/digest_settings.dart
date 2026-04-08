import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/filter_config.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/config_repository.dart';
import 'settings_section_card.dart';

// ============================================================
// 다이제스트 모드 설정 위젯 (F07)
// 활성화 토글 + 발송 시간 드롭다운으로 구성한다
// digest_enabled / digest_hour 키를 filter_config에서 읽고 쓴다
// ============================================================

class DigestSettings extends ConsumerWidget {
  final Map<String, FilterConfig> configs;

  const DigestSettings({super.key, required this.configs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = configs['digest_enabled']?.boolValue ?? false;
    final hour = configs['digest_hour']?.intValue ?? 9;

    return SettingsSectionCard(
      title: '다이제스트 모드',
      description: '활성화 시 매시 실행에서 수집만 하고, 지정 시간에 하루치를 묶어 발송합니다',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 활성화 토글
            Row(children: [
              Expanded(
                child: Text('다이제스트 모드 활성화',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              ),
              Switch(
                value: enabled,
                onChanged: (val) => _update(context, ref, 'digest_enabled', val ? 'true' : 'false'),
              ),
            ]),
            // 발송 시간 선택 (비활성화 시 흐리게 처리)
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: enabled ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: Row(children: [
                Text('발송 시간', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: hour.clamp(0, 23),
                  dropdownColor: AppColors.surfaceSecondary,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  underline: Container(height: 1, color: AppColors.border),
                  onChanged: enabled
                      ? (val) {
                          if (val != null) _update(context, ref, 'digest_hour', val.toString());
                        }
                      : null,
                  items: List.generate(24, (i) => i)
                      .map((h) => DropdownMenuItem(
                            value: h,
                            child: Text('$h시'),
                          ))
                      .toList(),
                ),
              ]),
            ),
          ],
        ),
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
