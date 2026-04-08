import 'package:flutter/material.dart';
import '../../../models/subscriber.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 구독자 목록 타일 위젯 — 개별 구독자 정보와 액션 버튼을 표시한다
// ============================================================

class SubscriberTile extends StatelessWidget {
  final Subscriber subscriber;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDelete;

  const SubscriberTile({
    super.key,
    required this.subscriber,
    this.onApprove,
    this.onReject,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // 아바타 — displayName이 비어 있을 때 '?'로 대체해 크래시를 방지한다
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceSecondary,
            child: Text(
              subscriber.displayName.isNotEmpty
                  ? subscriber.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          // 구독자 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      subscriber.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subscriber.isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'chat_id: ${subscriber.chatId}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 길이 보호 — 짧은 날짜 문자열에서 크래시를 방지한다
                    Text(
                      '신청: ${subscriber.requestedAt.length >= 10 ? subscriber.requestedAt.substring(0, 10) : subscriber.requestedAt}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    if (subscriber.approvedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '승인: ${subscriber.approvedAt!.length >= 10 ? subscriber.approvedAt!.substring(0, 10) : subscriber.approvedAt!}',
                        style: const TextStyle(color: AppColors.success, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // 액션 버튼들 — 좁은 너비에서 버튼이 넘치지 않도록 Wrap으로 감싼다
          Wrap(
            spacing: 0,
            runSpacing: 4,
            children: [
              if (onApprove != null)
                _actionButton('승인', AppColors.success, Icons.check, onApprove!),
              if (onReject != null)
                _actionButton('거부', AppColors.warning, Icons.block, onReject!),
              if (onDelete != null)
                _actionButton('삭제', AppColors.error, Icons.delete_outline, onDelete!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: label,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 14),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
          ),
        ),
      ),
    );
  }
}
