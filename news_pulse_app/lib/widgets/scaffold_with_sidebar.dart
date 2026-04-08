import 'package:flutter/material.dart';
import 'sidebar.dart';
import '../core/theme/app_theme.dart';

// ============================================================
// 사이드바를 포함한 기본 스캐폴드 — 모든 화면의 공통 레이아웃
// ============================================================

class ScaffoldWithSidebar extends StatefulWidget {
  /// 현재 선택된 네비게이션 인덱스
  final int selectedIndex;

  /// 표시할 화면 목록 (인덱스 순서대로)
  final List<Widget> screens;

  const ScaffoldWithSidebar({
    super.key,
    required this.selectedIndex,
    required this.screens,
  });

  @override
  State<ScaffoldWithSidebar> createState() => _ScaffoldWithSidebarState();
}

class _ScaffoldWithSidebarState extends State<ScaffoldWithSidebar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // 좌측 사이드바
          AppSidebar(
            selectedIndex: _selectedIndex,
            onIndexChanged: (index) {
              setState(() => _selectedIndex = index);
            },
          ),
          // 우측 메인 컨텐츠 영역
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: widget.screens,
            ),
          ),
        ],
      ),
    );
  }
}
