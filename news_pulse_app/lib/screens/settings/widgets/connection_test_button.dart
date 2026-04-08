import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 재사용 가능한 연결 테스트 버튼 (F12, F14 공용)
// 테스트 진행 중에는 로딩 인디케이터를 표시하고, 결과를 색상 Badge로 나타낸다
// ============================================================

enum TestStatus { idle, loading, success, failure }

class ConnectionTestButton extends StatefulWidget {
  /// 비동기 테스트 로직을 외부에서 주입한다 — true=성공, false=실패
  final Future<bool> Function() onTest;
  final String label;

  const ConnectionTestButton({
    super.key,
    required this.onTest,
    this.label = '테스트',
  });

  @override
  State<ConnectionTestButton> createState() => _ConnectionTestButtonState();
}

class _ConnectionTestButtonState extends State<ConnectionTestButton> {
  TestStatus _status = TestStatus.idle;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ElevatedButton(
        onPressed: _status == TestStatus.loading ? null : _runTest,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceSecondary,
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
        ),
        child: _status == TestStatus.loading
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
            : Text(widget.label, style: const TextStyle(fontSize: 12)),
      ),
      if (_status == TestStatus.success) ...[
        const SizedBox(width: 8),
        Icon(Icons.check_circle, color: AppColors.success, size: 16),
      ],
      if (_status == TestStatus.failure) ...[
        const SizedBox(width: 8),
        Icon(Icons.error, color: AppColors.error, size: 16),
      ],
    ]);
  }

  Future<void> _runTest() async {
    setState(() => _status = TestStatus.loading);
    try {
      final result = await widget.onTest();
      setState(() => _status = result ? TestStatus.success : TestStatus.failure);
    } catch (_) {
      setState(() => _status = TestStatus.failure);
    }
  }
}
