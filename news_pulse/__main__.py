"""
news-pulse 파이프라인 엔트리포인트. launchd에서 `python -m news_pulse`로 실행한다.

사용법:
  python -m news_pulse               # 일반 파이프라인 실행
  python -m news_pulse --health-check  # 헬스체크 전용 모드
  python -m news_pulse --manual-trigger  # 수동 실행 (진행 JSON stderr, 결과 JSON stdout)
  python -m news_pulse --catchup     # 놓친 시간대 일괄 실행
  python -m news_pulse --digest      # 다이제스트 강제 발송
"""
from __future__ import annotations

import argparse
import logging
import os
import signal
import sys
from pathlib import Path
from types import FrameType

# 로깅 설정 — launchd 환경에서는 stderr로 출력
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stderr,
)

logger = logging.getLogger(__name__)

# SIGTERM 수신 여부 플래그
_shutdown_requested = False


def _make_sigterm_handler(
    cleanup_callbacks: list[object],
) -> signal.Handlers:
    """SIGTERM 수신 시 정리 콜백을 실행하고 코드 0으로 종료하는 핸들러."""
    def _handler(signum: int, frame: FrameType | None) -> None:
        global _shutdown_requested
        _shutdown_requested = True
        logger.info("SIGTERM 수신 — 정리 작업 시작")
        for cb in cleanup_callbacks:
            try:
                if callable(cb):
                    cb()
            except Exception as exc:
                logger.warning("정리 콜백 실패: %s", exc)
        logger.info("SIGTERM 정리 완료, 코드 0으로 종료")
        sys.exit(0)
    return _handler


def run_pipeline() -> None:
    """일반 파이프라인 실행. SIGTERM 핸들러 등록 후 파이프라인을 실행한다."""
    from news_pulse.blocks.config_loader import EnvConfigLoader
    from news_pulse.blocks.model_engine.ollama_engine import OllamaEngine
    from news_pulse.db.migrate import migrate
    from news_pulse.db.store import SqliteStore
    from news_pulse.orchestrator import Pipeline

    here = Path(__file__).parent.parent
    candidate = here / ".env"
    env_path = str(candidate) if candidate.exists() else ".env"

    loader = EnvConfigLoader(env_path=env_path)
    config = loader.load()
    db_path = os.path.expanduser(config.db_path)
    migrate(db_path)

    with SqliteStore(db_path) as db:
        loader2 = EnvConfigLoader(env_path=env_path, db=db)
        config = loader2.load()
        ollama_engine = OllamaEngine(config.ollama_endpoint)
        signal.signal(
            signal.SIGTERM,
            _make_sigterm_handler([ollama_engine.unload_all, db.close]),
        )
        pipeline = Pipeline(config=config, db=db, ollama_engine=ollama_engine)
        pipeline.run()


def main() -> None:
    """CLI 인수를 파싱해 실행 모드를 결정한다."""
    parser = argparse.ArgumentParser(description="news-pulse 파이프라인")
    parser.add_argument("--health-check", action="store_true", help="헬스체크 모드")
    parser.add_argument("--manual-trigger", action="store_true", help="수동 실행 모드")
    parser.add_argument("--catchup", action="store_true", help="누락 시간대 일괄 실행")
    parser.add_argument("--digest", action="store_true", help="다이제스트 강제 발송")
    args = parser.parse_args()

    try:
        if args.health_check:
            from news_pulse.cli_commands import run_health_check
            run_health_check()
        elif args.manual_trigger:
            from news_pulse.cli_commands import run_manual_trigger
            run_manual_trigger()
        elif args.catchup:
            from news_pulse.cli_commands import run_catchup
            run_catchup()
        elif args.digest:
            from news_pulse.cli_commands import run_digest
            run_digest()
        else:
            run_pipeline()
    except Exception as exc:
        logger.exception("엔트리포인트 예외: %s", exc)
        sys.exit(1)


if __name__ == "__main__":
    main()
