import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/run_provider.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/run_detail_tile.dart';

// ============================================================
// 화면 4: 실행 이력
// 매시 실행 결과, 수집/필터/요약/전송 건수, 소요시간, 상태 표시
// ============================================================

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(recentRunsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '실행 이력',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '파이프라인 매시 실행 결과 목록 (최근 50건)',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => ref.invalidate(recentRunsProvider),
                  icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                  tooltip: '새로고침',
                ),
              ],
            ),
          ),
          // 컬럼 헤더
          _buildColumnHeader(),
          const Divider(color: AppColors.border, height: 1),
          // 이력 목록
          Expanded(
            child: runsAsync.when(
              data: (runs) {
                if (runs.isEmpty) {
                  return const Center(
                    child: Text(
                      '실행 기록이 없습니다',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: runs.length,
                  itemBuilder: (context, index) => RunDetailTile(run: runs[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('오류: $e', style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader() {
    // RunDetailTile 첫 번째 행과 동일한 위젯 구조를 사용해 헤더를 정렬한다:
    // Icon(16) + SizedBox(8) + 시작시각 + SizedBox(10) + 상태 + Spacer + 소요시간
    return Container(
      color: AppColors.surfacePrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          SizedBox(width: 16), // 상태 아이콘 자리
          SizedBox(width: 8),
          Text(
            '시작 시각',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          SizedBox(width: 10),
          Text(
            '상태',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          Spacer(),
          Text(
            '소요 시간',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
