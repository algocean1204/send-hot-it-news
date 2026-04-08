import 'package:flutter/material.dart';
import '../../../models/hot_news.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 핫뉴스 목록 타일 — hot_news 테이블 데이터를 영구 보관 목록으로 표시한다
// ============================================================

class HotNewsBadge extends StatelessWidget {
  final HotNews item;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const HotNewsBadge({
    super.key,
    required this.item,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핫뉴스 아이콘
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.local_fire_department, color: AppColors.warning, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.summaryKo,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 소스
                      _buildTag(item.source),
                      const SizedBox(width: 6),
                      // 판단 근거
                      _buildTag(_reasonLabel(item.hotReason), color: AppColors.warning),
                      const SizedBox(width: 8),
                      // 문자열 길이 보호 — 짧은 날짜 값에서 크래시를 방지한다
                      Text(
                        item.createdAt.length >= 10
                            ? item.createdAt.substring(0, 10)
                            : item.createdAt,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 수동 핫뉴스 해제 버튼 (manual 판단인 경우에만 표시)
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                tooltip: '핫뉴스 해제',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textSecondary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _reasonLabel(String reason) => switch (reason) {
    'upvote_auto' => '자동(업보트)',
    'source_auto' => '자동(소스)',
    'manual' => '수동 지정',
    _ => reason,
  };
}
