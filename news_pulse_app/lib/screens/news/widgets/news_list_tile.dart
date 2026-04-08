import 'package:flutter/material.dart';
import '../../../models/processed_item.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 뉴스 목록 타일 위젯 — 개별 뉴스 아이템을 목록에서 표시한다
// F03: 미읽음 파란 점 표시, 읽음 항목 투명도 감소
// ============================================================

class NewsListTile extends StatelessWidget {
  final ProcessedItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleHot;

  const NewsListTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggleHot,
  });

  @override
  Widget build(BuildContext context) {
    // 읽음 상태일 때 전체 타일 투명도를 낮춰 시각적으로 구분한다
    return Opacity(
      opacity: item.isRead ? 0.55 : 1.0,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // F03: 미읽음 파란 점 인디케이터
              _buildUnreadDot(),
              const SizedBox(width: 8),
              // 소스 배지
              _buildSourceBadge(),
              const SizedBox(width: 12),
              // 뉴스 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.summaryKo != null && item.summaryKo!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.summaryKo!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // 생성 시각 — 문자열 길이가 부족할 때 크래시를 방지한다
                        Text(
                          item.createdAt.length >= 16
                              ? item.createdAt.substring(0, 16)
                              : item.createdAt,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (item.upvotes > 0) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_upward, size: 11, color: AppColors.textMuted),
                          Text(
                            '${item.upvotes}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                        if (item.telegramSent) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.send, size: 11, color: AppColors.success),
                          const Text(
                            ' 전송됨',
                            style: TextStyle(color: AppColors.success, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 핫뉴스 토글 버튼
              IconButton(
                onPressed: onToggleHot,
                icon: Icon(
                  item.isHot ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                  color: item.isHot ? AppColors.warning : AppColors.textMuted,
                  size: 18,
                ),
                tooltip: item.isHot ? '핫뉴스 해제' : '핫뉴스로 지정',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// F03: 미읽음 상태 점 인디케이터 — 읽지 않은 경우 파란 점을 표시한다
  Widget _buildUnreadDot() {
    return SizedBox(
      width: 8,
      child: item.isRead
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
    );
  }

  Widget _buildSourceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        item.source,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
