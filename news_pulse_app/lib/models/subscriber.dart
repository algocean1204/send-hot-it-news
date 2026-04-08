// ============================================================
// subscribers 테이블 모델
// 텔레그램 구독자 정보를 표현한다
// ============================================================

enum SubscriberStatus { pending, approved, rejected }

class Subscriber {
  final int id;
  final int chatId;
  final String? username;
  final String? firstName;
  final SubscriberStatus status;
  final String requestedAt;
  final String? approvedAt;
  final String? rejectedAt;
  final bool isAdmin;

  const Subscriber({
    required this.id,
    required this.chatId,
    this.username,
    this.firstName,
    required this.status,
    required this.requestedAt,
    this.approvedAt,
    this.rejectedAt,
    required this.isAdmin,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory Subscriber.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'pending';
    final status = switch (statusStr) {
      'approved' => SubscriberStatus.approved,
      'rejected' => SubscriberStatus.rejected,
      _ => SubscriberStatus.pending,
    };

    return Subscriber(
      id: map['id'] as int,
      chatId: map['chat_id'] as int,
      username: map['username'] as String?,
      firstName: map['first_name'] as String?,
      status: status,
      requestedAt: map['requested_at'] as String,
      approvedAt: map['approved_at'] as String?,
      rejectedAt: map['rejected_at'] as String?,
      isAdmin: (map['is_admin'] as int? ?? 0) == 1,
    );
  }

  /// 표시용 이름을 반환한다 — username > first_name > chat_id 순으로 우선순위 적용
  String get displayName {
    if (username != null && username!.isNotEmpty) return '@$username';
    if (firstName != null && firstName!.isNotEmpty) return firstName!;
    return 'chat_id: $chatId';
  }
}
