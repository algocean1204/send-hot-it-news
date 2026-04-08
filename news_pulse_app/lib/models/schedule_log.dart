// ============================================================
// schedule_log 테이블 모델
// launchd 실행 스케줄 추적 — 놓친 실행 감지에 사용한다
// ============================================================

class ScheduleLog {
  final int id;
  final String scheduledAt;
  final String? actualAt;
  final String status;
  final String createdAt;

  const ScheduleLog({
    required this.id,
    required this.scheduledAt,
    this.actualAt,
    required this.status,
    required this.createdAt,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory ScheduleLog.fromMap(Map<String, dynamic> map) {
    return ScheduleLog(
      id: map['id'] as int,
      scheduledAt: map['scheduled_at'] as String,
      actualAt: map['actual_at'] as String?,
      status: map['status'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  /// 누락된 실행인지 여부 — status가 'missed'인 경우에 해당한다
  bool get isMissed => status == 'missed';
}
