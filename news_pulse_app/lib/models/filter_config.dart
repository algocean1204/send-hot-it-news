// ============================================================
// filter_config 테이블 모델
// 소스 ON/OFF, 필터 임계값 등 런타임 설정을 표현한다
// ============================================================

class FilterConfig {
  final int id;
  final String key;
  final String value;
  final String? description;
  final String updatedAt;

  const FilterConfig({
    required this.id,
    required this.key,
    required this.value,
    this.description,
    required this.updatedAt,
  });

  /// DB 맵에서 모델 객체를 생성한다
  factory FilterConfig.fromMap(Map<String, dynamic> map) {
    return FilterConfig(
      id: map['id'] as int,
      key: map['key'] as String,
      value: map['value'] as String,
      description: map['description'] as String?,
      updatedAt: map['updated_at'] as String,
    );
  }

  /// bool 타입 설정값을 파싱한다 (1/0 또는 true/false 문자열 처리)
  bool get boolValue {
    final v = value.toLowerCase();
    return v == '1' || v == 'true';
  }

  /// int 타입 설정값을 파싱한다
  int get intValue => int.tryParse(value) ?? 0;

  /// double 타입 설정값을 파싱한다
  double get doubleValue => double.tryParse(value) ?? 0.0;
}
