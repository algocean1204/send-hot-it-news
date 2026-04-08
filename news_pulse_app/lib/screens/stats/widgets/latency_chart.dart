import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/model_usage.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// F06: 모델별 평균 지연 추이 라인 차트
// X축 = 날짜, Y축 = 평균 latency(ms), 모델별 색상 구분
// ============================================================

/// 모델별 고정 색상 팔레트 — 최대 6개 모델을 구분한다
final List<Color> _kModelColors = [
  AppColors.accent,
  AppColors.success,
  AppColors.warning,
  AppColors.critical,
  AppColors.info,
  AppColors.textSecondary,
];

class LatencyChart extends StatelessWidget {
  final List<ModelLatencyPoint> data;

  const LatencyChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text('모델 사용 데이터 없음', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    // 모델 이름 목록을 추출해 색상을 배정한다
    final models = data.map((d) => d.modelName).toSet().toList()..sort();
    final colorMap = {
      for (var i = 0; i < models.length; i++)
        models[i]: _kModelColors[i % _kModelColors.length],
    };

    // 날짜 목록을 X축 인덱스로 변환한다
    final dates = data.map((d) => d.date).toSet().toList()..sort();
    final dateIndex = {for (var i = 0; i < dates.length; i++) dates[i]: i.toDouble()};

    // 모델별 FlSpot 목록 생성
    final barDataList = models.map((model) {
      final points = data
          .where((d) => d.modelName == model)
          .map((d) => FlSpot(dateIndex[d.date]!, d.avgLatencyMs))
          .toList();
      return LineChartBarData(
        spots: points,
        isCurved: true,
        color: colorMap[model]!,
        barWidth: 2,
        dotData: FlDotData(
          show: points.length <= 10,
          getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
            radius: 3,
            color: colorMap[model]!,
            strokeColor: AppColors.background,
            strokeWidth: 1.5,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: colorMap[model]!.withValues(alpha: 0.06),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '모델별 지연 추이 (최근 7일, 평균 ms)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // 범례
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: models.map((m) => _LegendItem(color: colorMap[m]!, label: m)).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              lineBarsData: barDataList,
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: AppColors.border, strokeWidth: 1),
                drawVerticalLine: false,
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                      // MM/dd 형식으로 축약해 표시한다
                      final d = dates[idx];
                      final label = d.length >= 10 ? d.substring(5) : d;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 9),
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
                    reservedSize: 40,
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
                    // barIndex를 통해 해당 모델 이름과 색상을 매핑한다
                    final barIdx = spot.barIndex.clamp(0, models.length - 1);
                    final model = models[barIdx];
                    return LineTooltipItem(
                      '${model.split('-').first}: ${spot.y.toStringAsFixed(0)}ms',
                      TextStyle(color: colorMap[model] ?? AppColors.textPrimary, fontSize: 12),
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
