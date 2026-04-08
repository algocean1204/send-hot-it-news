import 'package:flutter/material.dart';
import 'app_colors.dart';

// 기존 import 경로 호환을 위해 app_colors.dart를 재수출한다
export 'app_colors.dart';

// ============================================================
// 앱 테마 정의 — 다크/라이트 양 테마를 _buildTheme 헬퍼로 생성한다
// ============================================================

class AppTheme {
  /// 다크 테마 — GitHub 다크 계열
  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark, bg: DarkPalette.background,
    surface: DarkPalette.surfacePrimary, surfaceSecondary: DarkPalette.surfaceSecondary,
    surfaceTertiary: DarkPalette.surfaceTertiary, textPrimary: DarkPalette.textPrimary,
    textSecondary: DarkPalette.textSecondary, textMuted: DarkPalette.textMuted,
    accent: DarkPalette.accent, accentHover: DarkPalette.accentHover,
    errorColor: DarkPalette.error, borderColor: DarkPalette.border,
  );

  /// 라이트 테마 — 따뜻한 오프화이트 기반
  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light, bg: LightPalette.background,
    surface: LightPalette.surfacePrimary, surfaceSecondary: LightPalette.surfaceSecondary,
    surfaceTertiary: LightPalette.surfaceTertiary, textPrimary: LightPalette.textPrimary,
    textSecondary: LightPalette.textSecondary, textMuted: LightPalette.textMuted,
    accent: LightPalette.accent, accentHover: LightPalette.accentHover,
    errorColor: LightPalette.error, borderColor: LightPalette.border,
  );

  /// 공통 ThemeData 빌더 — 색상 파라미터만 달리 받아 중복을 제거한다
  static ThemeData _buildTheme({
    required Brightness brightness, required Color bg,
    required Color surface, required Color surfaceSecondary,
    required Color surfaceTertiary, required Color textPrimary,
    required Color textSecondary, required Color textMuted,
    required Color accent, required Color accentHover,
    required Color errorColor, required Color borderColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark
        ? ColorScheme.dark(
            surface: surface, primary: accent, secondary: accentHover,
            error: errorColor, onSurface: textPrimary,
            onPrimary: Colors.white, outline: borderColor,
          )
        : ColorScheme.light(
            surface: surface, primary: accent, secondary: accentHover,
            error: errorColor, onSurface: textPrimary,
            onPrimary: Colors.white, outline: borderColor,
          );
    final borderRadius6 = BorderRadius.circular(6);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        color: surface, elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor, width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 14),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
        bodySmall: TextStyle(color: textMuted, fontSize: 12),
        labelSmall: TextStyle(color: textMuted, fontSize: 11, fontFamily: 'monospace'),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface, foregroundColor: textPrimary,
        elevation: 0, surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent, unselectedLabelColor: textSecondary,
        indicatorColor: accent, dividerColor: borderColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: surfaceSecondary,
        border: OutlineInputBorder(borderRadius: borderRadius6, borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: borderRadius6, borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: borderRadius6, borderSide: BorderSide(color: accent)),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent, foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: borderRadius6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? Colors.white : textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? accent : surfaceTertiary;
        }),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surfaceSecondary),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: borderRadius6, side: BorderSide(color: borderColor),
          )),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent, thumbColor: accent,
        inactiveTrackColor: surfaceTertiary, overlayColor: accent.withAlpha(51),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceSecondary,
        contentTextStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: borderRadius6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
