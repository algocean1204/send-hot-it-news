// ============================================================
// health_check_results 테이블 모델
// 시스템 헬스체크 결과를 표현한다
// ============================================================

enum HealthStatus { ok, warning, error }

class HealthCheckResult {
  final int id;
  final String checkType;
  final String target;
  final HealthStatus status;
  final String? message;
  final int? responseTimeMs;
  final String createdAt;

  const HealthCheckResult({
    required this.id,
    required this.checkType,
    required this.target,
    required this.status,
    this.message,
    this.responseTimeMs,
    required this.createdAt,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory HealthCheckResult.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'error';
    final status = switch (statusStr) {
      'ok' => HealthStatus.ok,
      'warning' => HealthStatus.warning,
      _ => HealthStatus.error,
    };

    return HealthCheckResult(
      id: map['id'] as int,
      checkType: map['check_type'] as String,
      target: map['target'] as String,
      status: status,
      message: map['message'] as String?,
      responseTimeMs: map['response_time_ms'] as int?,
      createdAt: map['created_at'] as String,
    );
  }
}
