import 'dart:convert';
import 'dart:io';

// ============================================================
// F02: 파이프라인 수동 실행 서비스
// uv로 news_pulse 모듈을 실행하고 결과를 파싱한다
// ============================================================

/// 파이프라인 실행 결과를 담는 데이터 클래스
class PipelineResult {
  final int fetched;
  final int filtered;
  final int summarized;
  final int sent;
  final String status;

  const PipelineResult({
    required this.fetched,
    required this.filtered,
    required this.summarized,
    required this.sent,
    required this.status,
  });

  /// stdout JSON에서 결과를 파싱한다 — 파싱 실패 시 기본값을 사용한다
  factory PipelineResult.fromJson(Map<String, dynamic> json) {
    return PipelineResult(
      fetched: json['fetched'] as int? ?? 0,
      filtered: json['filtered'] as int? ?? 0,
      summarized: json['summarized'] as int? ?? 0,
      sent: json['sent'] as int? ?? 0,
      status: json['status'] as String? ?? 'done',
    );
  }

  /// JSON 파싱 실패 시 사용하는 기본 완료 결과
  const PipelineResult.empty()
      : fetched = 0,
        filtered = 0,
        summarized = 0,
        sent = 0,
        status = 'done';
}

/// Python 파이프라인을 uv로 실행하는 서비스
class PipelineRunner {
  /// 파이프라인을 실행하고 결과를 반환한다
  /// uv가 PATH에 없으면 예외를 던진다
  static Future<PipelineResult> run() async {
    final process = await Process.start(
      'uv',
      ['run', 'python', '-m', 'news_pulse', '--manual-trigger'],
      // Python 백엔드 루트 디렉토리를 작업 경로로 지정한다
      workingDirectory: _findProjectRoot(),
    );

    // stdout 전체를 수집한다 — 파이프라인이 JSON 결과를 stdout으로 출력한다
    final stdoutBuffer = StringBuffer();
    process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);

    // 프로세스 완료를 기다린다
    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      final stderrOutput = await process.stderr.transform(utf8.decoder).join();
      throw Exception('파이프라인 실행 실패 (exit $exitCode): $stderrOutput');
    }

    // stdout에서 JSON 결과를 파싱한다
    final output = stdoutBuffer.toString().trim();
    try {
      // stdout 마지막 줄이 JSON 결과일 것으로 기대한다
      final lastLine = output.split('\n').lastWhere(
        (line) => line.trim().startsWith('{'),
        orElse: () => '',
      );
      if (lastLine.isNotEmpty) {
        final json = jsonDecode(lastLine) as Map<String, dynamic>;
        return PipelineResult.fromJson(json);
      }
    } catch (_) {
      // JSON 파싱 실패 시 빈 결과를 반환한다
    }

    return const PipelineResult.empty();
  }

  /// 프로젝트 루트 디렉토리를 찾는다
  static String _findProjectRoot() {
    // HOME 기준으로 news-pulse 프로젝트 루트를 찾는다
    final home = Platform.environment['HOME'] ?? '.';
    final projectPath = Platform.environment['NEWS_PULSE_ROOT'] ??
        '$home/.news-pulse';
    return projectPath;
  }
}
