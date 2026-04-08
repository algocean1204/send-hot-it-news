import 'package:flutter/services.dart';

// ============================================================
// 메뉴바 MethodChannel 정의
// tray_manager 패키지로 대부분 처리하지만, 네이티브 NSStatusBar 직접 접근이 필요한 경우를 위해 채널을 보관한다
// ============================================================

class MenuBarChannel {
  static const MethodChannel _channel = MethodChannel('com.news_pulse/menu_bar');

  /// 채널을 통해 네이티브에 메뉴바 아이콘 상태를 전달한다
  static Future<void> setDotColor(String color) async {
    try {
      await _channel.invokeMethod('setDotColor', {'color': color});
    } on MissingPluginException {
      // 네이티브 구현 없음 — tray_manager로 대체한다
    }
  }
}
