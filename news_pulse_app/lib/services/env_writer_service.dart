import 'dart:io';

// ============================================================
// .env 파일 읽기/쓰기 서비스
// Python 파이프라인이 읽는 .env 파일의 특정 키 값을 Flutter에서 교체한다
// .env 파일은 프로젝트 루트에 위치한다고 가정한다
// ============================================================

class EnvWriterService {
  /// macOS에서 앱 번들 상위의 프로젝트 루트를 탐색해 .env 경로를 반환한다
  /// 실제 배포 시에는 앱 설정에서 .env 경로를 지정할 수 있도록 확장이 필요하다
  String _findEnvPath() {
    // 앱 실행 경로를 기준으로 올라가며 .env를 탐색한다
    final execDir = File(Platform.resolvedExecutable).parent;
    // macOS 앱 번들 구조: .app/Contents/MacOS/runner -> 프로젝트 루트 탐색
    var dir = execDir;
    for (int i = 0; i < 8; i++) {
      final candidate = File('${dir.path}/.env');
      if (candidate.existsSync()) return candidate.path;
      dir = dir.parent;
    }
    // 탐색 실패 시 현재 디렉토리의 .env를 사용한다
    return '.env';
  }

  /// .env 파일에서 특정 키의 값을 교체하고 파일을 다시 쓴다
  Future<void> updateKey(String key, String value) async {
    final path = _findEnvPath();
    final file = File(path);
    String content = '';
    if (await file.exists()) {
      content = await file.readAsString();
    }

    final lines = content.split('\n');
    bool found = false;
    final updated = lines.map((line) {
      // 공백 포함 KEY= 패턴에도 대응한다
      if (line.startsWith('$key=') || line.startsWith('$key =')) {
        found = true;
        return '$key=$value';
      }
      return line;
    }).toList();

    // 키가 없으면 파일 끝에 추가한다
    if (!found) {
      updated.add('$key=$value');
    }

    await file.writeAsString(updated.join('\n'));
  }

  /// .env 파일에서 특정 키의 현재 값을 읽는다
  Future<String?> readKey(String key) async {
    final path = _findEnvPath();
    final file = File(path);
    if (!await file.exists()) return null;
    final lines = await file.readAsLines();
    for (final line in lines) {
      if (line.startsWith('$key=')) {
        return line.substring(key.length + 1).trim();
      }
    }
    return null;
  }
}
