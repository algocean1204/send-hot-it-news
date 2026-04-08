import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 마크다운 내보내기 다이얼로그 — 하위 위젯 모음
// export_dialog.dart에서 분리된 UI 구성 요소
// ============================================================

/// 다이얼로그 타이틀 바 (아이콘 + 제목 + 닫기 버튼)
class ExportTitleBar extends StatelessWidget {
  final VoidCallback onClose;

  const ExportTitleBar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.download_outlined, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '마크다운 내보내기',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

/// 날짜 범위 선택 영역 (시작일 ~ 종료일)
class ExportDateRangeSelector extends StatelessWidget {
  final String startLabel;
  final String endLabel;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;

  const ExportDateRangeSelector({
    super.key,
    required this.startLabel,
    required this.endLabel,
    required this.onStartTap,
    required this.onEndTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '날짜 범위',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: DateButton(label: startLabel, onTap: onStartTap)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('~', style: TextStyle(color: AppColors.textSecondary)),
            ),
            Expanded(child: DateButton(label: endLabel, onTap: onEndTap)),
          ],
        ),
      ],
    );
  }
}

/// 핫뉴스만 내보내기 토글 스위치
class ExportHotOnlyToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ExportHotOnlyToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '핫뉴스만 내보내기',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// 내보내기 결과 배너 (성공/오류 공용)
class ExportResultBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const ExportResultBanner({super.key, required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.success;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}

/// 날짜 선택 버튼 (캘린더 아이콘 + 텍스트)
class DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const DateButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
