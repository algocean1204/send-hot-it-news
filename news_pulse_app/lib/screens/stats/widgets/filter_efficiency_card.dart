import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 필터링 효율 카드 — 수집/필터/전송 평균 비율을 요약한다
// ============================================================

class FilterEfficiencyCard extends StatelessWidget {
  final List<Map<String, int>> runs;

  const FilterEfficiencyCard({super.key, required this.runs});

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return Center(child: Text('데이터 없음', style: TextStyle(color: AppColors.textMuted)));
    }

    // 최근 실행들의 평균 건수를 계산한다
    final count = runs.length;
    final totalFetched = runs.fold<int>(0, (s, r) => s + (r['fetched'] ?? 0));
    final totalFiltered = runs.fold<int>(0, (s, r) => s + (r['filtered'] ?? 0));
    final totalSent = runs.fold<int>(0, (s, r) => s + (r['sent'] ?? 0));

    final avgFetched = count > 0 ? totalFetched / count : 0.0;
    final avgFiltered = count > 0 ? totalFiltered / count : 0.0;
    final avgSent = count > 0 ? totalSent / count : 0.0;

    final filterRate = avgFetched > 0 ? (avgFiltered / avgFetched * 100) : 0.0;
    final sendRate = avgFiltered > 0 ? (avgSent / avgFiltered * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '필터링 효율 (최근 30회 평균)',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _efficiencyRow('수집', avgFetched, null, AppColors.info),
        const SizedBox(height: 10),
        _efficiencyRow('필터 통과', avgFiltered, filterRate, AppColors.accent),
        const SizedBox(height: 10),
        _efficiencyRow('전송', avgSent, sendRate, AppColors.success),
      ],
    );
  }

  Widget _efficiencyRow(String label, double avg, double? rate, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(avg.toStringAsFixed(1), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('건/회', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  if (rate != null) ...[
                    const SizedBox(width: 8),
                    Text('(${rate.toStringAsFixed(0)}%)', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: rate != null ? (rate / 100).clamp(0.0, 1.0) : 1.0,
                  backgroundColor: AppColors.surfaceSecondary,
                  color: color,
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
