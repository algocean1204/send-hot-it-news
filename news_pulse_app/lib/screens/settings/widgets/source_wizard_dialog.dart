import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/config_repository.dart';
import 'source_wizard_steps.dart';

// 소스 추가 위저드 다이얼로그 (F12) — 단계별 위젯은 source_wizard_steps.dart에 분리

/// 외부에서 다이얼로그를 표시한다
Future<void> showSourceWizardDialog(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    builder: (_) => const _SourceWizardDialog(),
  );
}

class _SourceWizardDialog extends ConsumerStatefulWidget {
  const _SourceWizardDialog();
  @override
  ConsumerState<_SourceWizardDialog> createState() => _SourceWizardDialogState();
}

class _SourceWizardDialogState extends ConsumerState<_SourceWizardDialog> {
  int _step = 0;
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  String _detectedParser = '';
  int _tier = 2;
  String _language = 'EN';
  String _previewTitle = '';
  bool _testPassed = false;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfacePrimary,
      title: Row(children: [
        const Text('새 소스 추가', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        const Spacer(),
        _StepIndicator(step: _step),
      ]),
      content: SizedBox(width: 480, child: _buildStep()),
      actions: _buildActions(),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return Step1UrlInput(
          controller: _urlController,
          detectedParser: _detectedParser,
          onDetect: (parser) => setState(() => _detectedParser = parser),
        );
      case 1:
        return Step2Config(
          nameController: _nameController,
          tier: _tier,
          language: _language,
          url: _urlController.text,
          detectedParser: _detectedParser,
          onTierChanged: (t) => setState(() => _tier = t),
          onLanguageChanged: (l) => setState(() => _language = l),
        );
      case 2:
        return Step3Preview(
          url: _urlController.text,
          sourceName: _nameController.text,
          previewTitle: _previewTitle,
          testPassed: _testPassed,
          onTestResult: (ok, title) => setState(() {
            _testPassed = ok;
            _previewTitle = title;
          }),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _buildActions() {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소', style: TextStyle(color: AppColors.textMuted)),
      ),
      if (_step > 0)
        TextButton(
          onPressed: () => setState(() => _step--),
          child: const Text('이전', style: TextStyle(color: AppColors.textSecondary)),
        ),
      if (_step < 2)
        ElevatedButton(
          onPressed: _canAdvance() ? () => setState(() => _step++) : null,
          child: const Text('다음'),
        ),
      if (_step == 2)
        ElevatedButton(
          onPressed: _testPassed ? () => _save() : null,
          child: const Text('저장'),
        ),
    ];
  }

  bool _canAdvance() {
    if (_step == 0) return _urlController.text.trim().isNotEmpty && _detectedParser.isNotEmpty;
    if (_step == 1) return _nameController.text.trim().isNotEmpty;
    return false;
  }

  Future<void> _save() async {
    final source = {
      'url': _urlController.text.trim(), 'name': _nameController.text.trim(),
      'parser_type': _detectedParser, 'tier': _tier, 'language': _language,
    };
    final dbAsync = ref.read(databaseProvider);
    await dbAsync.when(
      data: (db) async {
        await ConfigRepository(db).saveCustomSource(source);
        if (mounted) Navigator.pop(context);
      },
      loading: () async {},
      error: (e, _) async {},
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});
  @override
  Widget build(BuildContext context) {
    return Row(children: List.generate(3, (i) => Container(
      width: 8, height: 8,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: i == step ? AppColors.accent : AppColors.surfaceTertiary,
      ),
    )));
  }
}
