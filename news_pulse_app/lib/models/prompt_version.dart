// ============================================================
// prompt_versions 테이블 모델
// 요약/번역 프롬프트의 버전 이력을 표현한다 — 어떤 버전이 활성인지 추적한다
// ============================================================

class PromptVersion {
  final int id;
  final String promptType; // 'summarize_ko' | 'summarize_en' | 'translate'
  final int version;
  final String content;
  final bool isActive;
  final String createdAt;

  const PromptVersion({
    required this.id,
    required this.promptType,
    required this.version,
    required this.content,
    required this.isActive,
    required this.createdAt,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory PromptVersion.fromMap(Map<String, dynamic> map) {
    return PromptVersion(
      id: map['id'] as int,
      promptType: map['prompt_type'] as String,
      version: map['version'] as int,
      content: map['content'] as String,
      isActive: (map['is_active'] as int) == 1,
      createdAt: map['created_at'] as String,
    );
  }

  /// 프롬프트 유형의 표시 레이블을 반환한다
  String get typeLabel {
    switch (promptType) {
      case 'summarize_ko':
        return '한국어 요약';
      case 'summarize_en':
        return '영어 요약';
      case 'translate':
        return '번역';
      default:
        return promptType;
    }
  }
}
