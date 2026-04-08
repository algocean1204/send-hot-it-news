import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/run_history.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 소요 시간 추이 차트 — 최근 30개 실행의 총 소요시간을 라인 차트로 표시한다
// ============================================================

class DurationChart extends StatelessWidget {
  final List<RunHistory> runs;

  const DurationChart({super.key, required this.runs});

  @override
  Widget build(BuildContext context) {
    // 소요시간이 있는 실행만 필터링하고 시간순으로 정렬한다
    final validRuns = runs
        .where((r) => r.totalDurationMs != null)
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    if (validRuns.isEmpty) {
      return const Center(
        child: Text('데이터 없음', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final spots = validRuns.asMap().entries.map((entry) {
      final durationSec = (entry.value.totalDurationMs! / 1000).toDouble();
      return FlSpot(entry.key.toDouble(), durationSec);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '실행 소요 시간 추이 (최근 30회)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.accent,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: spots.length <= 10,
                    getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.accent,
                      strokeColor: AppColors.background,
                      strokeWidth: 1.5,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.accent.withValues(alpha: 0.08),
                  ),
                ),
              ],
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              titlesData: FlTitlesData(
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toStringAsFixed(0)}s',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                    reservedSize: 36,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => AppColors.surfaceSecondary,
                  getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)}s',
                      const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
