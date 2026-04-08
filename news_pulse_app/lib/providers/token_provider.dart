import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/secure_storage_service.dart';
import '../services/env_writer_service.dart';

// ============================================================
// 토큰 관련 Provider — 민감 설정값의 로드/저장 상태를 관리한다
// ============================================================

/// 관리 대상 토큰 키 목록 — 순서대로 UI에 표시한다
const List<String> kManagedTokenKeys = [
  'BOT_TOKEN',
  'ADMIN_CHAT_ID',
  'OLLAMA_ENDPOINT',
  'APEX_MODEL_NAME',
  'KANANA_MODEL_NAME',
  'MEMORY_THRESHOLD_GB',
];

/// SecureStorageService Provider
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// EnvWriterService Provider
final envWriterServiceProvider = Provider<EnvWriterService>((ref) {
  return EnvWriterService();
});

/// 키별 저장된 토큰 값 Provider — 각 키를 독립적으로 조회한다
final tokenValueProvider = FutureProvider.autoDispose.family<String?, String>((ref, key) async {
  final service = ref.watch(secureStorageServiceProvider);
  return service.read(key);
});

/// 특정 키의 편집 모드 상태 — true이면 입력 필드를 노출한다
final tokenEditingProvider = StateProvider.family<bool, String>((ref, key) => false);
