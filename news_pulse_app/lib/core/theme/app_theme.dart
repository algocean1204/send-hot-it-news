import 'package:flutter/material.dart';

// ============================================================
// 앱 테마 정의 — Claude/Cursor 스타일 다크 테마 기반
// awesome-design-md 참고: 개발자 친화적 다크 테마
// ============================================================

class AppColors {
  // 기본 배경 계층
  static const Color background = Color(0xFF0D1117);       // 최외곽 배경 (GitHub 다크 계열)
  static const Color surfacePrimary = Color(0xFF161B22);   // 카드/패널 배경
  static const Color surfaceSecondary = Color(0xFF21262D); // 호버/선택 배경
  static const Color surfaceTertiary = Color(0xFF30363D);  // 입력 필드/구분선

  // 사이드바
  static const Color sidebarBg = Color(0xFF010409);        // 사이드바 배경 (더 진한 검정)
  static const Color sidebarSelected = Color(0xFF1F6FEB);  // 선택된 항목 (GitHub 파란색)
  static const Color sidebarHover = Color(0xFF21262D);     // 호버 상태

  // 텍스트
  static const Color textPrimary = Color(0xFFE6EDF3);      // 주 텍스트
  static const Color textSecondary = Color(0xFF8B949E);    // 보조 텍스트
  static const Color textMuted = Color(0xFF484F58);        // 흐린 텍스트

  // 액센트 컬러
  static const Color accent = Color(0xFF1F6FEB);           // 파란색 (주요 액션)
  static const Color accentHover = Color(0xFF388BFD);      // 파란색 호버

  // 상태 색상
  static const Color success = Color(0xFF3FB950);          // 성공 (초록)
  static const Color warning = Color(0xFFD29922);          // 경고 (주황)
  static const Color error = Color(0xFFF85149);            // 에러 (빨강)
  static const Color info = Color(0xFF58A6FF);             // 정보 (하늘색)
  static const Color critical = Color(0xFFFF7B72);         // 심각 (연한 빨강)

  // 구분선
  static const Color border = Color(0xFF30363D);
  static const Color borderSubtle = Color(0xFF21262D);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surfacePrimary,
        primary: AppColors.accent,
        secondary: AppColors.accentHover,
        error: AppColors.error,
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.white,
        outline: AppColors.border,
      ),
      // 카드 스타일
      cardTheme: CardThemeData(
        color: AppColors.surfacePrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),
      // 텍스트 스타일
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        bodySmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
      // 앱바 스타일
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfacePrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      // 탭바 스타일
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.accent,
        dividerColor: AppColors.border,
      ),
      // 입력 필드 스타일
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      // 버튼 스타일
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      // 스위치 스타일
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.surfaceTertiary;
        }),
      ),
      // 드롭다운 스타일
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(AppColors.surfaceSecondary),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ),
      // 슬라이더 스타일
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        thumbColor: AppColors.accent,
        inactiveTrackColor: AppColors.surfaceTertiary,
        overlayColor: Color(0x331F6FEB),
      ),
      // 구분선 스타일
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      // 스낵바 스타일
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceSecondary,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
