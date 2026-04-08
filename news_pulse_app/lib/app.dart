import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'widgets/scaffold_with_sidebar.dart';
import 'screens/home/home_screen.dart';
import 'screens/news/news_screen.dart';
import 'screens/subscribers/subscribers_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/errors/errors_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/settings/settings_screen.dart';

// ============================================================
// 앱 루트 위젯 — MaterialApp 설정 및 7개 화면 라우팅을 정의한다
// ============================================================

class NewsPulseApp extends StatelessWidget {
  const NewsPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'news-pulse 대시보드',
      debugShowCheckedModeBanner: false,
      // 다크 테마만 사용한다 (themeMode를 dark로 강제)
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const _AppShell(),
    );
  }
}

/// 7개 화면을 IndexedStack으로 관리하는 앱 셸
class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    return const ScaffoldWithSidebar(
      selectedIndex: 0,
      screens: [
        HomeScreen(),
        NewsScreen(),
        SubscribersScreen(),
        HistoryScreen(),
        ErrorsScreen(),
        StatsScreen(),
        SettingsScreen(),
      ],
    );
  }
}
