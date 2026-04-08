// ============================================================
// whitelist_keywords 테이블 모델
// 사용자가 등록한 관심 키워드를 표현한다 — Tier3 아이템이 이 키워드를 포함하면 업보트 무관하게 통과
// ============================================================

class WhitelistKeyword {
  final int id;
  final String keyword;
  final String createdAt;

  const WhitelistKeyword({
    required this.id,
    required this.keyword,
    required this.createdAt,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory WhitelistKeyword.fromMap(Map<String, dynamic> map) {
    return WhitelistKeyword(
      id: map['id'] as int,
      keyword: map['keyword'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
