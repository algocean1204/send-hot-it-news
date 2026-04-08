import 'dart:io';
import '../models/processed_item.dart';

// ============================================================
// F10: 마크다운 내보내기 서비스
// 뉴스 아이템 목록을 마크다운 문자열로 변환하고 파일로 저장한다
// ============================================================

class MarkdownExporter {
  /// 뉴스 아이템 목록에서 마크다운 문자열을 생성한다
  /// 핫뉴스를 먼저, 이후 일반 뉴스 순으로 출력한다
  static String generate(List<ProcessedItem> items) {
    final hot = items.where((i) => i.isHot).toList();
    final general = items.where((i) => !i.isHot).toList();

    final buffer = StringBuffer();

    buffer.writeln('# News Pulse 뉴스 내보내기');
    buffer.writeln();
    buffer.writeln(
      '> 생성 시각: ${DateTime.now().toIso8601String().substring(0, 16)}',
    );
    buffer.writeln('> 전체 ${items.length}건 (핫뉴스 ${hot.length}건)');
    buffer.writeln();

    if (hot.isNotEmpty) {
      buffer.writeln('## 핫뉴스 (${hot.length}건)');
      buffer.writeln();
      for (final item in hot) {
        _writeItem(buffer, item);
      }
    }

    if (general.isNotEmpty) {
      buffer.writeln('## 일반 뉴스 (${general.length}건)');
      buffer.writeln();
      for (final item in general) {
        _writeItem(buffer, item);
      }
    }

    return buffer.toString();
  }

  static void _writeItem(StringBuffer buffer, ProcessedItem item) {
    buffer.writeln('### ${item.title}');
    buffer.writeln();

    // 메타 정보 — 소스, 언어, 수집 시각
    buffer.writeln(
      '**소스**: ${item.source} | '
      '**언어**: ${item.language} | '
      '**수집**: ${item.createdAt.length >= 16 ? item.createdAt.substring(0, 16) : item.createdAt}',
    );

    if (item.upvotes > 0) {
      buffer.writeln('**업보트**: ${item.upvotes}');
    }
    buffer.writeln();

    if (item.summaryKo != null && item.summaryKo!.isNotEmpty) {
      buffer.writeln('**요약**');
      buffer.writeln();
      buffer.writeln('> ${item.summaryKo!.replaceAll('\n', '\n> ')}');
      buffer.writeln();
    }

    if (item.tags.isNotEmpty) {
      buffer.writeln('**태그**: ${item.tags.map((t) => '`$t`').join(' ')}');
      buffer.writeln();
    }

    buffer.writeln('**원문**: ${item.url}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
  }

  /// 마크다운을 파일에 저장한다 — 경로가 지정되지 않으면 임시 파일을 사용한다
  static Future<String> saveToFile(String markdown, String? path) async {
    final filePath = path ??
        '${Platform.environment['HOME'] ?? '.'}/Desktop/news_pulse_export_${DateTime.now().millisecondsSinceEpoch}.md';

    final file = File(filePath);
    await file.writeAsString(markdown, encoding: const SystemEncoding());
    return filePath;
  }
}
