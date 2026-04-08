import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 파이프라인 성공률 차트 — 경로별(apex/kanana/claude) 처리 건수를 파이 차트로 표시한다
// ============================================================

class PipelineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const PipelineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text('데이터 없음', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final total = data.fold<int>(0, (sum, row) => sum + (row['cnt'] as int? ?? 0));
    if (total == 0) {
      return Center(
        child: Text('데이터 없음', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final colors = [AppColors.accent, AppColors.success, AppColors.warning];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '파이프라인 경로별 처리 건수',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: PieChart(
                PieChartData(
                  sections: data.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final row = entry.value;
                    final cnt = row['cnt'] as int? ?? 0;
                    final pct = total > 0 ? cnt / total * 100 : 0.0;
                    return PieChartSectionData(
                      color: colors[idx % colors.length],
                      value: cnt.toDouble(),
                      title: '${pct.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      radius: 55,
                    );
                  }).toList(),
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 범례
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: data.asMap().entries.map((entry) {
                final idx = entry.key;
                final row = entry.value;
                final path = row['pipeline_path'] as String? ?? 'unknown';
                final cnt = row['cnt'] as int? ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[idx % colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$path ($cnt건)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }
}
