import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 소스별 건수 차트 — 최근 7일 소스별 뉴스 수집 건수를 막대 차트로 표시한다
// ============================================================

class SourceChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const SourceChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text('데이터 없음', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    // 소스별로 총 건수를 집계한다
    final sourceMap = <String, int>{};
    for (final row in data) {
      final source = row['source'] as String? ?? 'unknown';
      final cnt = row['cnt'] as int? ?? 0;
      sourceMap[source] = (sourceMap[source] ?? 0) + cnt;
    }

    final sources = sourceMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sources.isEmpty) {
      return Center(
        child: Text('데이터 없음', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '소스별 수집 건수 (최근 7일)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              barGroups: sources.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.value.toDouble(),
                      color: _sourceColor(entry.key),
                      width: 20,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ],
                );
              }).toList(),
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= sources.length) return const SizedBox.shrink();
                      final name = sources[idx].key;
                      // 소스명이 길면 잘라서 표시한다
                      final label = name.length > 8 ? name.substring(0, 8) : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      );
                    },
                    reservedSize: 24,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt()}',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                    reservedSize: 28,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Color _sourceColor(int index) {
    // 소스 인덱스에 따라 앱 테마 색상을 순환 적용한다 — 하드코딩 없이 AppColors만 사용한다
    final colors = [
      AppColors.accent,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
      AppColors.critical,
      AppColors.textSecondary,
      AppColors.accentHover,
      AppColors.success,
    ];
    return colors[index % colors.length];
  }
}
