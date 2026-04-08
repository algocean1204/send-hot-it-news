import 'package:flutter/material.dart';
import '../../../models/error_log.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 에러 로그 타일 — 개별 에러 항목을 표시한다
// ============================================================

class ErrorListTile extends StatefulWidget {
  final ErrorLog error;

  const ErrorListTile({super.key, required this.error});

  @override
  State<ErrorListTile> createState() => _ErrorListTileState();
}

class _ErrorListTileState extends State<ErrorListTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(widget.error.severity);

    return Container(
      decoration: BoxDecoration(
        border: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        color: _expanded ? AppColors.surfaceSecondary.withValues(alpha: 0.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.error.traceback != null
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 심각도 배지
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _severityLabel(widget.error.severity),
                      style: TextStyle(
                        color: severityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 모듈명 + 메시지
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '[${widget.error.module}] ',
                                style: const TextStyle(
                                  color: AppColors.info,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              TextSpan(
                                text: widget.error.message,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.error.createdAt,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 스택 트레이스 확장 아이콘
                  if (widget.error.traceback != null)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
            ),
          ),
          // 스택 트레이스 확장 영역 — 최대 높이를 제한하고 스크롤 가능하게 한다
          if (_expanded && widget.error.traceback != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.error.traceback!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _severityLabel(ErrorSeverity s) => switch (s) {
    ErrorSeverity.info => 'INFO',
    ErrorSeverity.warning => 'WARN',
    ErrorSeverity.error => 'ERROR',
    ErrorSeverity.critical => 'CRIT',
  };

  Color _severityColor(ErrorSeverity s) => switch (s) {
    ErrorSeverity.info => AppColors.info,
    ErrorSeverity.warning => AppColors.warning,
    ErrorSeverity.error => AppColors.error,
    ErrorSeverity.critical => AppColors.critical,
  };
}
