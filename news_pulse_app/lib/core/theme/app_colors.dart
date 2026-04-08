import 'package:flutter/material.dart';

// ============================================================
// 앱 색상 정의 — 다크/라이트 팔레트 + 동적 색상 게터
// ============================================================

/// 다크 모드 색상 팔레트
class DarkPalette {
  static const background = Color(0xFF0D1117);
  static const surfacePrimary = Color(0xFF161B22);
  static const surfaceSecondary = Color(0xFF21262D);
  static const surfaceTertiary = Color(0xFF30363D);
  static const sidebarBg = Color(0xFF010409);
  static const sidebarSelected = Color(0xFF1F6FEB);
  static const sidebarHover = Color(0xFF21262D);
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF484F58);
  static const accent = Color(0xFF1F6FEB);
  static const accentHover = Color(0xFF388BFD);
  static const success = Color(0xFF3FB950);
  static const warning = Color(0xFFD29922);
  static const error = Color(0xFFF85149);
  static const info = Color(0xFF58A6FF);
  static const critical = Color(0xFFFF7B72);
  static const border = Color(0xFF30363D);
  static const borderSubtle = Color(0xFF21262D);
}

/// 라이트 모드 색상 팔레트 (#FAF9F5 기반 따뜻한 오프화이트)
class LightPalette {
  static const background = Color(0xFFFAF9F5);
  static const surfacePrimary = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF0EFEB);
  static const surfaceTertiary = Color(0xFFE5E4E0);
  static const sidebarBg = Color(0xFFF2F1ED);
  static const sidebarSelected = Color(0xFF1F6FEB);
  static const sidebarHover = Color(0xFFE8E7E3);
  static const textPrimary = Color(0xFF1F2328);
  static const textSecondary = Color(0xFF656D76);
  static const textMuted = Color(0xFF8C959F);
  static const accent = Color(0xFF1F6FEB);
  static const accentHover = Color(0xFF0969DA);
  static const success = Color(0xFF1A7F37);
  static const warning = Color(0xFF9A6700);
  static const error = Color(0xFFCF222E);
  static const info = Color(0xFF0969DA);
  static const critical = Color(0xFFCF222E);
  static const border = Color(0xFFD1D9E0);
  static const borderSubtle = Color(0xFFE8E7E3);
}

/// 현재 테마에 따라 색상을 반환하는 동적 색상 클래스
/// 위젯 코드에서 AppColors.textPrimary 등으로 접근한다
class AppColors {
  static bool _isDark = false;

  /// 테마 변경 시 호출한다 — app.dart에서만 사용
  static void setDark(bool value) => _isDark = value;

  static Color get background =>
      _isDark ? DarkPalette.background : LightPalette.background;
  static Color get surfacePrimary =>
      _isDark ? DarkPalette.surfacePrimary : LightPalette.surfacePrimary;
  static Color get surfaceSecondary =>
      _isDark ? DarkPalette.surfaceSecondary : LightPalette.surfaceSecondary;
  static Color get surfaceTertiary =>
      _isDark ? DarkPalette.surfaceTertiary : LightPalette.surfaceTertiary;
  static Color get sidebarBg =>
      _isDark ? DarkPalette.sidebarBg : LightPalette.sidebarBg;
  static Color get sidebarSelected =>
      _isDark ? DarkPalette.sidebarSelected : LightPalette.sidebarSelected;
  static Color get sidebarHover =>
      _isDark ? DarkPalette.sidebarHover : LightPalette.sidebarHover;
  static Color get textPrimary =>
      _isDark ? DarkPalette.textPrimary : LightPalette.textPrimary;
  static Color get textSecondary =>
      _isDark ? DarkPalette.textSecondary : LightPalette.textSecondary;
  static Color get textMuted =>
      _isDark ? DarkPalette.textMuted : LightPalette.textMuted;
  static Color get accent =>
      _isDark ? DarkPalette.accent : LightPalette.accent;
  static Color get accentHover =>
      _isDark ? DarkPalette.accentHover : LightPalette.accentHover;
  static Color get success =>
      _isDark ? DarkPalette.success : LightPalette.success;
  static Color get warning =>
      _isDark ? DarkPalette.warning : LightPalette.warning;
  static Color get error =>
      _isDark ? DarkPalette.error : LightPalette.error;
  static Color get info =>
      _isDark ? DarkPalette.info : LightPalette.info;
  static Color get critical =>
      _isDark ? DarkPalette.critical : LightPalette.critical;
  static Color get border =>
      _isDark ? DarkPalette.border : LightPalette.border;
  static Color get borderSubtle =>
      _isDark ? DarkPalette.borderSubtle : LightPalette.borderSubtle;
}
