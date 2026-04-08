import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pipeline_runner.dart';

// ============================================================
// F02: 수동 트리거 상태 관리
// idle → running → done/error 상태 전환을 관리한다
// ============================================================

/// 수동 트리거 실행 상태
enum TriggerState { idle, running, done, error }

/// 수동 트리거 상태 + 결과를 담는 데이터 클래스
class TriggerStatus {
  final TriggerState state;
  final PipelineResult? result;
  final String? errorMessage;

  const TriggerStatus({
    required this.state,
    this.result,
    this.errorMessage,
  });

  const TriggerStatus.idle() : this(state: TriggerState.idle);
}

/// 수동 트리거 StateNotifier — 버튼 클릭 시 파이프라인을 실행하고 상태를 갱신한다
class ManualTriggerNotifier extends StateNotifier<TriggerStatus> {
  ManualTriggerNotifier() : super(const TriggerStatus.idle());

  /// 파이프라인을 실행한다 — 이미 실행 중이면 무시한다
  Future<void> run() async {
    if (state.state == TriggerState.running) return;

    state = const TriggerStatus(state: TriggerState.running);
    try {
      final result = await PipelineRunner.run();
      state = TriggerStatus(state: TriggerState.done, result: result);
    } catch (e) {
      state = TriggerStatus(
        state: TriggerState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 상태를 초기화한다
  void reset() {
    state = const TriggerStatus.idle();
  }
}

final manualTriggerProvider =
    StateNotifierProvider<ManualTriggerNotifier, TriggerStatus>(
  (ref) => ManualTriggerNotifier(),
);
