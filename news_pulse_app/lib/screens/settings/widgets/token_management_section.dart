import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../../providers/token_provider.dart';
import 'connection_test_button.dart';
import 'settings_section_card.dart';

// ============================================================
// 토큰 및 환경변수 관리 섹션 (F14)
// 마스킹된 값을 표시하고 "수정" → 입력 → "저장" + "테스트" 흐름을 제공한다
// 저장 시 macOS Keychain + .env 파일을 동시에 갱신한다
// ============================================================

class TokenManagementSection extends ConsumerWidget {
  const TokenManagementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      title: '토큰 및 환경변수 관리',
      description: 'Telegram 봇 토큰, 모델 설정 등 민감 값을 안전하게 관리한다',
      child: Column(
        children: kManagedTokenKeys
            .map((key) => _TokenRow(tokenKey: key))
            .toList(),
      ),
    );
  }
}

/// 단일 토큰 키의 표시/편집 행
class _TokenRow extends ConsumerStatefulWidget {
  final String tokenKey;
  const _TokenRow({required this.tokenKey});

  @override
  ConsumerState<_TokenRow> createState() => _TokenRowState();
}

class _TokenRowState extends ConsumerState<_TokenRow> {
  final _editController = TextEditingController();

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valueAsync = ref.watch(tokenValueProvider(widget.tokenKey));
    final isEditing = ref.watch(tokenEditingProvider(widget.tokenKey));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 키 이름
        Text(widget.tokenKey,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (!isEditing) ...[
          // 마스킹된 값 표시 행
          Row(children: [
            Expanded(
              child: valueAsync.when(
                data: (val) => Text(
                  val != null ? _mask(val) : '(미설정)',
                  style: TextStyle(
                      color: val != null ? AppColors.textPrimary : AppColors.textMuted,
                      fontSize: 13,
                      fontFamily: 'monospace'),
                ),
                loading: () => Text('...', style: TextStyle(color: AppColors.textMuted)),
                error: (e, s) => Text('읽기 오류', style: TextStyle(color: AppColors.error)),
              ),
            ),
            TextButton(
              onPressed: () {
                final current = valueAsync.value ?? '';
                _editController.text = current;
                ref.read(tokenEditingProvider(widget.tokenKey).notifier).state = true;
              },
              child: Text('수정', style: TextStyle(color: AppColors.accent, fontSize: 12)),
            ),
            // BOT_TOKEN인 경우에만 Telegram 연결 테스트 버튼을 표시한다
            if (widget.tokenKey == 'BOT_TOKEN')
              ConnectionTestButton(
                label: '테스트',
                onTest: () => _testTelegram(valueAsync.value ?? ''),
              ),
          ]),
        ] else ...[
          // 편집 입력 필드
          TextField(
            controller: _editController,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'monospace'),
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            obscureText: widget.tokenKey == 'BOT_TOKEN',
          ),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton(
              onPressed: () => _save(context),
              child: const Text('저장', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                ref.read(tokenEditingProvider(widget.tokenKey).notifier).state = false;
              },
              child: Text('취소', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ]),
        ],
      ]),
    );
  }

  /// 앞 6자만 보이고 나머지를 *로 마스킹한다
  String _mask(String val) {
    if (val.length <= 6) return '*' * val.length;
    return '${val.substring(0, 6)}${'*' * (val.length - 6).clamp(4, 20)}';
  }

  Future<void> _save(BuildContext context) async {
    final newVal = _editController.text.trim();
    if (newVal.isEmpty) return;

    final secureService = ref.read(secureStorageServiceProvider);
    final envService = ref.read(envWriterServiceProvider);

    // Keychain + .env 동시 저장
    await secureService.write(widget.tokenKey, newVal);
    await envService.updateKey(widget.tokenKey, newVal);

    ref.read(tokenEditingProvider(widget.tokenKey).notifier).state = false;
    ref.invalidate(tokenValueProvider(widget.tokenKey));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.tokenKey} 저장 완료',
            style: TextStyle(color: AppColors.textPrimary))),
      );
    }
  }

  /// Telegram getMe API로 BOT_TOKEN 유효성을 검사한다
  Future<bool> _testTelegram(String token) async {
    if (token.isEmpty) return false;
    try {
      final res = await http
          .get(Uri.parse('https://api.telegram.org/bot$token/getMe'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
