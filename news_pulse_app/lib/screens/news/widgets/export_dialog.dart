import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/news_repository.dart';
import '../../../models/processed_item.dart';
import '../../../services/markdown_exporter.dart';
import 'export_sub_widgets.dart';

// F10: 마크다운 내보내기 다이얼로그 — 하위 위젯은 export_sub_widgets.dart에 분리

class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _hotOnly = false;
  bool _isExporting = false;
  String? _exportedPath;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy. MM. dd');
    return Dialog(
      backgroundColor: AppColors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExportTitleBar(onClose: () => Navigator.of(context).pop()),
              const SizedBox(height: 20),
              ExportDateRangeSelector(
                startLabel: fmt.format(_startDate),
                endLabel: fmt.format(_endDate),
                onStartTap: () => _pickDate(context, isStart: true),
                onEndTap: () => _pickDate(context, isStart: false),
              ),
              const SizedBox(height: 16),
              ExportHotOnlyToggle(
                value: _hotOnly,
                onChanged: (v) => setState(() => _hotOnly = v),
              ),
              const SizedBox(height: 20),
              if (_exportedPath != null)
                ExportResultBanner(message: '저장 완료: $_exportedPath'),
              if (_error != null)
                ExportResultBanner(message: '오류: $_error', isError: true),
              const SizedBox(height: 4),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: AppColors.border),
          ),
          child: const Text('닫기'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _isExporting ? null : _doExport,
          icon: _isExporting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 14),
          label: Text(_isExporting ? '처리 중...' : '내보내기'),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final first = DateTime.now().subtract(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // 시작일이 종료일 이후이면 종료일을 시작일로 맞춘다
          if (_startDate.isAfter(_endDate)) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _doExport() async {
    setState(() { _isExporting = true; _exportedPath = null; _error = null; });
    try {
      final dbAsync = ref.read(databaseProvider);
      List<ProcessedItem> items = [];
      // AsyncValue에서 DB 인스턴스를 직접 추출해 사용한다
      final db = dbAsync.valueOrNull;
      if (db != null) {
        final repo = NewsRepository(db);
        items = await repo.getItemsByDateRange(_startDate, _endDate);
      }

      // 핫뉴스만 옵션 적용
      final filtered = _hotOnly ? items.where((i) => i.isHot).toList() : items;
      final markdown = MarkdownExporter.generate(filtered);
      final path = await MarkdownExporter.saveToFile(markdown, null);

      setState(() {
        _exportedPath = path;
        _isExporting = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isExporting = false;
      });
    }
  }
}
