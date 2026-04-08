import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 구독자 검색 위젯 — username 또는 chat_id로 검색할 수 있다
// ============================================================

class SubscriberSearch extends StatefulWidget {
  final ValueChanged<String> onSearch;

  const SubscriberSearch({super.key, required this.onSearch});

  @override
  State<SubscriberSearch> createState() => _SubscriberSearchState();
}

class _SubscriberSearchState extends State<SubscriberSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: _controller,
        // setState를 호출해 suffixIcon 표시 상태를 갱신한다
        onChanged: (value) {
          setState(() {});
          widget.onSearch(value);
        },
        decoration: InputDecoration(
          hintText: 'username 또는 chat_id 검색',
          prefixIcon: Icon(Icons.search, size: 16, color: AppColors.textSecondary),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                    widget.onSearch('');
                  },
                  icon: Icon(Icons.clear, size: 14, color: AppColors.textSecondary),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
    );
  }
}
