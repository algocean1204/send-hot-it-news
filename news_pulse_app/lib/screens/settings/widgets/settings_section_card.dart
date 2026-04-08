import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 설정 섹션 공통 카드 컨테이너 — 제목+설명 헤더와 content 영역을 감싼다
// 모든 설정 섹션이 이 카드를 공유해 일관된 외관을 유지한다
// ============================================================

class SettingsSectionCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(description,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          child,
        ],
      ),
    );
  }
}
