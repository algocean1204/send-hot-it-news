import 'package:flutter/material.dart';
import '../../../models/processed_item.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 뉴스 상세 내용 위젯 — 요약, 태그, URL, 메타 칩을 렌더링한다
// ============================================================

/// 뉴스 상세 다이얼로그의 본문 영역
class NewsDetailContent extends StatelessWidget {
  final ProcessedItem item;

  const NewsDetailContent({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 메타 정보 행 (소스, 언어, 파이프라인, 처리 시간, 업보트)
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _MetaChip(icon: Icons.source_outlined, text: item.source),
            _MetaChip(icon: Icons.language, text: item.language),
            if (item.pipelinePath != null)
              _MetaChip(icon: Icons.route_outlined, text: item.pipelinePath!),
            if (item.processingTimeMs != null)
              _MetaChip(icon: Icons.timer_outlined, text: '${item.processingTimeMs}ms'),
            if (item.upvotes > 0)
              _MetaChip(icon: Icons.arrow_upward, text: '${item.upvotes}'),
          ],
        ),
        const SizedBox(height: 16),
        // 한국어 요약
        if (item.summaryKo != null && item.summaryKo!.isNotEmpty) ...[
          _sectionLabel('요약'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.summaryKo!,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // 태그
        if (item.tags.isNotEmpty) ...[
          _sectionLabel('태그'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: item.tags.map((tag) => _TagChip(tag: tag)).toList(),
          ),
          const SizedBox(height: 16),
        ],
        // 원문 URL
        _sectionLabel('원문 URL'),
        const SizedBox(height: 4),
        Text(
          item.url,
          style: TextStyle(
            color: AppColors.info,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 16),
        // F04: 모델 추적 정보 — 요약/번역 모델명이 기록된 경우 표시한다
        if (item.summarizerModel != null || item.translatorModel != null) ...[
          const SizedBox(height: 16),
          _sectionLabel('모델 정보'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (item.summarizerModel != null)
                _MetaChip(
                  icon: Icons.psychology_outlined,
                  text: '요약: ${item.summarizerModel!}',
                ),
              if (item.translatorModel != null)
                _MetaChip(
                  icon: Icons.translate,
                  text: '번역: ${item.translatorModel!}',
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // 수집 시각
        Text(
          '수집 시각: ${item.createdAt}',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// 메타 정보 칩 (아이콘 + 텍스트)
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

/// 태그 칩 위젯
class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(tag, style: TextStyle(color: AppColors.info, fontSize: 11)),
    );
  }
}
