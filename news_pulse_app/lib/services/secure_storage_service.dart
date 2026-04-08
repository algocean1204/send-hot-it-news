import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ============================================================
// macOS Keychain 래퍼 서비스 — flutter_secure_storage를 통해 민감 값을 안전하게 저장한다
// Python 파이프라인이 읽는 .env와 별도로 앱 내 안전 저장소를 유지한다
// ============================================================

class SecureStorageService {
  // macOS Keychain 옵션 — 앱 재설치 후에도 데이터를 보존한다
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      accountName: 'news_pulse',
      // 잠금 해제 상태에서만 접근 가능하도록 설정한다
      accessibility: KeychainAccessibility.unlocked,
    ),
  );

  /// 키체인에서 값을 읽는다
  Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  /// 키체인에 값을 저장한다
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// 키체인에서 값을 삭제한다
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// 키체인의 모든 항목을 읽는다
  Future<Map<String, String>> readAll() async {
    return _storage.readAll();
  }
}
