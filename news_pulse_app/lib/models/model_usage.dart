// ============================================================
// model_usage_log 테이블 모델
// 모델별 추론 소요시간 기록 — 지연 추이 차트에 사용한다
// ============================================================

class ModelUsage {
  final int id;
  final int? runId;
  final int? processedItemId;
  final String modelName;
  final String taskType;
  final int latencyMs;
  final int? inputTokens;
  final bool success;
  final String createdAt;

  const ModelUsage({
    required this.id,
    this.runId,
    this.processedItemId,
    required this.modelName,
    required this.taskType,
    required this.latencyMs,
    this.inputTokens,
    required this.success,
    required this.createdAt,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory ModelUsage.fromMap(Map<String, dynamic> map) {
    return ModelUsage(
      id: map['id'] as int,
      runId: map['run_id'] as int?,
      processedItemId: map['processed_item_id'] as int?,
      modelName: map['model_name'] as String,
      taskType: map['task_type'] as String,
      latencyMs: map['latency_ms'] as int,
      inputTokens: map['input_tokens'] as int?,
      success: (map['success'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
    );
  }
}

/// 날짜별 모델 평균 지연 시간 집계 결과
class ModelLatencyPoint {
  final String modelName;
  final String date;
  final double avgLatencyMs;

  const ModelLatencyPoint({
    required this.modelName,
    required this.date,
    required this.avgLatencyMs,
  });
}
