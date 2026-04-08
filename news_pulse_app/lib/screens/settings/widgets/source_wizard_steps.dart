import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import 'connection_test_button.dart';

// ============================================================
// 소스 추가 위저드 — 단계별 위젯 (Step1 ~ Step3)
// source_wizard_dialog.dart에서 분리된 하위 위젯 모음
// ============================================================

/// URL 패턴으로 파서 타입을 자동 감지한다
String detectParserType(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('reddit.com')) return 'reddit';
  if (lower.contains('github.com') && lower.contains('.atom')) return 'github_atom';
  if (lower.contains('.atom')) return 'rss';
  if (lower.contains('/rss') || lower.contains('.rss') || lower.contains('.xml')) return 'rss';
  if (lower.contains('algolia') || lower.contains('/api/')) return 'algolia';
  return '';
}

// ─── Step 1: URL 입력 + 파서 자동 감지 ─────────────────────────

class Step1UrlInput extends StatelessWidget {
  final TextEditingController controller;
  final String detectedParser;
  final ValueChanged<String> onDetect;

  const Step1UrlInput({
    super.key,
    required this.controller,
    required this.detectedParser,
    required this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('소스 URL을 입력하세요', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 12),
      TextField(
        controller: controller,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: const InputDecoration(hintText: 'https://example.com/rss', isDense: true),
        onChanged: (v) => onDetect(detectParserType(v)),
      ),
      const SizedBox(height: 12),
      if (detectedParser.isNotEmpty)
        Row(children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 16),
          const SizedBox(width: 6),
          Text('파서 타입 감지됨: $detectedParser',
              style: TextStyle(color: AppColors.success, fontSize: 12)),
        ])
      else
        Text('URL을 입력하면 파서 타입을 자동 감지합니다',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ]);
  }
}

// ─── Step 2: 소스 이름 / Tier / 언어 설정 ──────────────────────

class Step2Config extends StatelessWidget {
  final TextEditingController nameController;
  final int tier;
  final String language;
  final String url;
  final String detectedParser;
  final ValueChanged<int> onTierChanged;
  final ValueChanged<String> onLanguageChanged;

  const Step2Config({
    super.key,
    required this.nameController, required this.tier, required this.language,
    required this.url, required this.detectedParser,
    required this.onTierChanged, required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('소스 정보를 입력하세요', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 12),
      TextField(
        controller: nameController,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: const InputDecoration(labelText: '소스 이름', isDense: true),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Text('Tier', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 16),
        ...List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
            selected: tier == i + 1,
            onSelected: (_) => onTierChanged(i + 1),
            selectedColor: AppColors.accent,
            backgroundColor: AppColors.surfaceSecondary,
          ),
        )),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Text('언어', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 16),
        ...['KO', 'EN'].map((l) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(l, style: const TextStyle(fontSize: 12)),
            selected: language == l,
            onSelected: (_) => onLanguageChanged(l),
            selectedColor: AppColors.accent,
            backgroundColor: AppColors.surfaceSecondary,
          ),
        )),
      ]),
    ]);
  }
}

// ─── Step 3: 연결 테스트 + 미리보기 ────────────────────────────

class Step3Preview extends StatelessWidget {
  final String url;
  final String sourceName;
  final String previewTitle;
  final bool testPassed;
  final void Function(bool, String) onTestResult;

  const Step3Preview({
    super.key,
    required this.url, required this.sourceName,
    required this.previewTitle, required this.testPassed,
    required this.onTestResult,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('연결을 테스트하세요', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 12),
      ConnectionTestButton(
        label: '연결 테스트',
        onTest: () => _runTest(),
      ),
      const SizedBox(height: 12),
      if (previewTitle.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('첫 번째 아이템 미리보기',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Text(previewTitle,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          ]),
        ),
      if (!testPassed && previewTitle.isEmpty)
        Text('테스트 버튼을 눌러 연결을 확인하세요',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ]);
  }

  /// HTTP GET으로 URL 연결을 테스트하고 첫 번째 title을 추출한다
  Future<bool> _runTest() async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        // XML/RSS에서 첫 번째 title을 간단히 추출한다
        final body = res.body;
        final match = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(body);
        final title = match?.group(1) ?? '(제목 파싱 불가)';
        onTestResult(true, title);
        return true;
      }
    } catch (_) {}
    onTestResult(false, '');
    return false;
  }
}
