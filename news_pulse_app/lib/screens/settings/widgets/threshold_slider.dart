import 'package:flutter/material.dart';
import '../../../models/filter_config.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// 임계값 슬라이더 타일 — 필터 임계값을 슬라이더+텍스트 필드로 조정한다
// ============================================================

class ThresholdSlider extends StatefulWidget {
  final FilterConfig config;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<String> onChanged;

  const ThresholdSlider({
    super.key,
    required this.config,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  State<ThresholdSlider> createState() => _ThresholdSliderState();
}

class _ThresholdSliderState extends State<ThresholdSlider> {
  late double _currentValue;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.config.doubleValue.clamp(widget.min, widget.max);
    _textController = TextEditingController(text: _currentValue.toInt().toString());
  }

  @override
  void didUpdateWidget(ThresholdSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부에서 값이 변경된 경우 동기화한다
    if (oldWidget.config.value != widget.config.value) {
      _currentValue = widget.config.doubleValue.clamp(widget.min, widget.max);
      _textController.text = _currentValue.toInt().toString();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 설정 키 이름
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatKey(widget.config.key),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.config.description != null)
                      Text(
                        widget.config.description!,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 직접 입력 필드
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _textController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  onSubmitted: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null) {
                      final clamped = parsed.clamp(widget.min, widget.max);
                      setState(() {
                        _currentValue = clamped;
                        _textController.text = clamped.toInt().toString();
                      });
                      widget.onChanged(clamped.toInt().toString());
                    }
                  },
                ),
              ),
            ],
          ),
          // 슬라이더
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: _currentValue,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              label: _currentValue.toInt().toString(),
              onChanged: (val) {
                setState(() {
                  _currentValue = val;
                  _textController.text = val.toInt().toString();
                });
              },
              onChangeEnd: (val) {
                widget.onChanged(val.toInt().toString());
              },
            ),
          ),
          // 범위 표시
          Row(
            children: [
              Text(
                '${widget.min.toInt()}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              const Spacer(),
              Text(
                '${widget.max.toInt()}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    // 언더스코어 구분자를 공백으로 변환하여 읽기 좋게 만든다
    return key.replaceAll('_', ' ').toUpperCase();
  }
}
