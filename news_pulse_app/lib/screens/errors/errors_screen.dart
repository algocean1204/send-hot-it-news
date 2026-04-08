import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/error_provider.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/error_list_tile.dart';
import 'widgets/health_check_panel.dart';

// ============================================================
// 화면 5: 오류 로그 + 헬스체크
// 에러 목록 + 심각도 필터 + 헬스체크 수동 실행
// ============================================================

class ErrorsScreen extends ConsumerWidget {
  const ErrorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오류 로그 & 헬스체크',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '에러 로그 조회 및 시스템 헬스체크 실행',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.border, height: 1),
            // 탭바
            Container(
              color: AppColors.surfacePrimary,
              child: const TabBar(
                tabs: [
                  Tab(text: '오류 로그'),
                  Tab(text: '헬스체크'),
                ],
              ),
            ),
            // 탭 내용
            Expanded(
              child: TabBarView(
                children: [
                  const _ErrorLogTab(),
                  const HealthCheckPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 오류 로그 탭 내용
class _ErrorLogTab extends ConsumerWidget {
  const _ErrorLogTab();

  static const _severityOptions = ['all', 'info', 'warning', 'error', 'critical'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(errorSeverityFilterProvider);
    final errorsAsync = ref.watch(filteredErrorsProvider);

    return Column(
      children: [
        // 필터 + 새로고침
        Container(
          color: AppColors.surfacePrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '심각도 필터:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 8),
              // 심각도 드롭다운 필터
              DropdownButton<String?>(
                value: currentFilter,
                isDense: true,
                dropdownColor: AppColors.surfaceSecondary,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                items: [
                  const DropdownMenuItem(value: null, child: Text('전체')),
                  ..._severityOptions.skip(1).map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())),
                  ),
                ],
                onChanged: (val) {
                  ref.read(errorSeverityFilterProvider.notifier).state = val;
                },
              ),
              const Spacer(),
              IconButton(
                onPressed: () => ref.invalidate(filteredErrorsProvider),
                icon: Icon(Icons.refresh, size: 16, color: AppColors.textSecondary),
                tooltip: '새로고침',
              ),
            ],
          ),
        ),
        Divider(color: AppColors.border, height: 1),
        // 에러 목록
        Expanded(
          child: errorsAsync.when(
            data: (errors) {
              if (errors.isEmpty) {
                return Center(
                  child: Text(
                    '에러 로그가 없습니다',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              return ListView.builder(
                itemCount: errors.length,
                itemBuilder: (context, index) => ErrorListTile(error: errors[index]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('오류: $e', style: TextStyle(color: AppColors.error)),
            ),
          ),
        ),
      ],
    );
  }
}
