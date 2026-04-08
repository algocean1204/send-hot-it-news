import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
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
// themeProvider를 감시하여 라이트/다크 테마를 동적으로 전환한다
// ============================================================

class NewsPulseApp extends ConsumerWidget {
  const NewsPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    AppColors.setDark(themeMode == ThemeMode.dark);

    return MaterialApp(
      title: 'news-pulse 대시보드',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
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
