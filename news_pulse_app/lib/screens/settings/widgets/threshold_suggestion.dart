import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/calibration_provider.dart';
import '../../../providers/config_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/config_repository.dart';
import 'settings_section_card.dart';

// ============================================================
// 임계값 교정 제안 위젯 (F09)
// 소스별 통과율과 제안 임계값을 테이블로 표시한다
// "적용" 클릭 시 filter_config를 즉시 업데이트한다
// ============================================================

class ThresholdSuggestion extends ConsumerWidget {
  final Map<String, dynamic> currentConfigs;

  const ThresholdSuggestion({super.key, required this.currentConfigs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calibrationsAsync = ref.watch(calibrationProvider);

    return SettingsSectionCard(
      title: '임계값 교정 제안',
      description: '최근 30일 소스별 통과율을 기반으로 최적 임계값을 제안합니다',
      child: calibrationsAsync.when(
        data: (results) {
          if (results.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('분석 데이터가 없습니다 (30일 이상 수집 필요)',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            );
          }
          return Column(children: [
            // 테이블 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(children: [
                Expanded(child: Text('소스', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                SizedBox(width: 60, child: Text('통과율', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                SizedBox(width: 40, child: Text('건수', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                SizedBox(width: 50),
              ]),
            ),
            const Divider(color: AppColors.border, height: 1),
            ...results.map((r) => _buildRow(context, ref, r)),
          ]);
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

  Widget _buildRow(BuildContext context, WidgetRef ref, CalibrationResult r) {
    final passRatePct = (r.passRate * 100).toStringAsFixed(1);
    // 통과율이 목표 범위(30-50%)를 벗어나면 강조한다
    final isOutOfRange = r.passRate < 0.30 || r.passRate > 0.50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(children: [
        Expanded(
          child: Text(r.source,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
        ),
        SizedBox(
          width: 60,
          child: Text('$passRatePct%',
              style: TextStyle(
                  color: isOutOfRange ? AppColors.warning : AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          width: 40,
          child: Text('${r.totalCount}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ),
        // 해당 filter_config 키가 있을 때만 "적용" 버튼을 표시한다
        if (r.suggestedThresholdKey != null && isOutOfRange)
          SizedBox(
            width: 50,
            child: TextButton(
              onPressed: () => _apply(context, ref, r),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 28),
              ),
              child: const Text('적용', style: TextStyle(color: AppColors.accent, fontSize: 11)),
            ),
          )
        else
          const SizedBox(width: 50),
      ]),
    );
  }

  /// 제안 임계값을 filter_config에 반영한다
  /// 단순 휴리스틱: 통과율이 너무 낮으면 임계값을 20% 낮추고, 너무 높으면 20% 높인다
  Future<void> _apply(BuildContext context, WidgetRef ref, CalibrationResult r) async {
    final key = r.suggestedThresholdKey!;
    final currentStr = currentConfigs[key]?.toString() ?? '50';
    final current = int.tryParse(currentStr) ?? 50;
    final suggested = r.passRate < 0.30
        ? (current * 0.8).round()
        : (current * 1.2).round();

    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        await ConfigRepository(db).updateValue(key, suggested.toString());
        ref.invalidate(configMapProvider);
        ref.invalidate(calibrationProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$key → $suggested 적용 완료',
                style: const TextStyle(color: AppColors.textPrimary))),
          );
        }
      },
      loading: () async {},
      error: (e, _) async {},
    );
  }
}
