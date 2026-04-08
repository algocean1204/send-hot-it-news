// ============================================================
// run_history 테이블 모델
// 파이프라인 실행 기록을 표현한다
// ============================================================

enum RunStatus { running, success, partialFailure, failure }

class RunHistory {
  final int id;
  final String startedAt;
  final String? finishedAt;
  final RunStatus status;
  final int fetchedCount;
  final int filteredCount;
  final int summarizedCount;
  final int sentCount;
  final int? totalDurationMs;
  final int? modelLoadMs;
  final int? inferenceMs;
  final String? memoryMode;
  final String? errorMessage;

  const RunHistory({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    required this.status,
    required this.fetchedCount,
    required this.filteredCount,
    required this.summarizedCount,
    required this.sentCount,
    this.totalDurationMs,
    this.modelLoadMs,
    this.inferenceMs,
    this.memoryMode,
    this.errorMessage,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory RunHistory.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'running';
    final status = switch (statusStr) {
      'success' => RunStatus.success,
      'partial_failure' => RunStatus.partialFailure,
      'failure' => RunStatus.failure,
      _ => RunStatus.running,
    };

    return RunHistory(
      id: map['id'] as int,
      startedAt: map['started_at'] as String,
      finishedAt: map['finished_at'] as String?,
      status: status,
      fetchedCount: map['fetched_count'] as int? ?? 0,
      filteredCount: map['filtered_count'] as int? ?? 0,
      summarizedCount: map['summarized_count'] as int? ?? 0,
      sentCount: map['sent_count'] as int? ?? 0,
      totalDurationMs: map['total_duration_ms'] as int?,
      modelLoadMs: map['model_load_ms'] as int?,
      inferenceMs: map['inference_ms'] as int?,
      memoryMode: map['memory_mode'] as String?,
      errorMessage: map['error_message'] as String?,
    );
  }

  /// 총 소요시간을 사람이 읽기 쉬운 문자열로 변환한다
  String get durationDisplay {
    if (totalDurationMs == null) return '-';
    final seconds = totalDurationMs! / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = (seconds / 60).floor();
    final remainingSec = (seconds % 60).toStringAsFixed(0);
    return '${minutes}m ${remainingSec}s';
  }
}
