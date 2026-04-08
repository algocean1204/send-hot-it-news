// ============================================================
// error_log 테이블 모델
// 파이프라인 에러 로그를 표현한다
// ============================================================

enum ErrorSeverity { info, warning, error, critical }

class ErrorLog {
  final int id;
  final int? runId;
  final ErrorSeverity severity;
  final String module;
  final String message;
  final String? traceback;
  final String createdAt;

  const ErrorLog({
    required this.id,
    this.runId,
    required this.severity,
    required this.module,
    required this.message,
    this.traceback,
    required this.createdAt,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory ErrorLog.fromMap(Map<String, dynamic> map) {
    final severityStr = map['severity'] as String? ?? 'error';
    final severity = switch (severityStr) {
      'info' => ErrorSeverity.info,
      'warning' => ErrorSeverity.warning,
      'critical' => ErrorSeverity.critical,
      _ => ErrorSeverity.error,
    };

    return ErrorLog(
      id: map['id'] as int,
      runId: map['run_id'] as int?,
      severity: severity,
      module: map['module'] as String,
      message: map['message'] as String,
      traceback: map['traceback'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
