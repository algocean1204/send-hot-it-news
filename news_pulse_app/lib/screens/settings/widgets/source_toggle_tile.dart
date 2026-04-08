import 'package:flutter/material.dart';
import '../../../models/filter_config.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 소스 ON/OFF 토글 타일 — 개별 뉴스 소스의 활성화 상태를 스위치로 제어한다
// ============================================================

class SourceToggleTile extends StatelessWidget {
  final FilterConfig config;
  final ValueChanged<bool> onChanged;

  const SourceToggleTile({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // 소스 이름
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatSourceKey(config.key),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (config.description != null)
                  Text(
                    config.description!,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          // 활성화 스위치
          Switch(
            value: config.boolValue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// source_geeknews_enabled -> GeekNews 형태로 변환한다
  String _formatSourceKey(String key) {
    // source_X_enabled 패턴에서 소스명만 추출한다
    final match = RegExp(r'source_(.+)_enabled').firstMatch(key);
    if (match == null) return key;
    final name = match.group(1) ?? key;
    // 언더스코어를 공백으로 변환하고 첫 글자를 대문자로
    return name.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}
