import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants.dart';

// ============================================================
// 사이드바 네비게이션 위젯 — macOS 스타일의 좌측 사이드바
// ============================================================

/// 네비게이션 항목 데이터 모델
class NavItem {
  final IconData icon;
  final String label;
  final int index;

  const NavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  static const List<NavItem> _navItems = [
    NavItem(icon: Icons.dashboard_outlined, label: '홈', index: 0),
    NavItem(icon: Icons.article_outlined, label: '날짜별 뉴스', index: 1),
    NavItem(icon: Icons.people_outlined, label: '구독자 관리', index: 2),
    NavItem(icon: Icons.history_outlined, label: '실행 이력', index: 3),
    NavItem(icon: Icons.error_outline, label: '오류/헬스체크', index: 4),
    NavItem(icon: Icons.bar_chart_outlined, label: '통계', index: 5),
    NavItem(icon: Icons.settings_outlined, label: '설정', index: 6),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kSidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 앱 타이틀 영역
          _buildHeader(),
          const Divider(color: AppColors.border, height: 1),
          // 네비게이션 항목 목록
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _navItems
                  .map((item) => _buildNavItem(context, item))
                  .toList(),
            ),
          ),
          // 하단 버전 정보
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.rss_feed,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'news-pulse',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'macOS 대시보드',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, NavItem item) {
    final isSelected = selectedIndex == item.index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        onTap: () => onIndexChanged(item.index),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.sidebarSelected : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                item.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: const Text(
        'v1.0.0',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
    );
  }
}
