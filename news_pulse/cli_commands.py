"""
CLI 서브커맨드 구현 모듈.

수동 트리거, 캐치업, 다이제스트, 헬스체크 등 __main__.py에서 분리된 명령어들이다.
"""
from __future__ import annotations

import json
import logging
import os
import sys
from pathlib import Path

from news_pulse.models.config import Config

logger = logging.getLogger(__name__)

# 중복 실행 방지용 락 파일
_LOCK_FILENAME = "news_pulse.lock"


def _acquire_lock(data_dir: str) -> Path | None:
    """락 파일을 획득한다. 이미 실행 중이면 None을 반환한다."""
    lock_path = Path(data_dir) / _LOCK_FILENAME
    if lock_path.exists():
        try:
            existing_pid = int(lock_path.read_text().strip())
            if Path(f"/proc/{existing_pid}").exists():
                return None
        except (ValueError, OSError):
            pass
    lock_path.write_text(str(os.getpid()))
    return lock_path


def _release_lock(lock_path: Path) -> None:
    """락 파일을 해제한다."""
    try:
        lock_path.unlink(missing_ok=True)
    except OSError as exc:
        logger.warning("락 파일 해제 실패: %s", exc)


def _emit_progress(stage: str, count: int) -> None:
    """수동 트리거 모드에서 진행 상황을 JSON Line으로 stderr에 출력한다."""
    progress = json.dumps({"stage": stage, "count": count}, ensure_ascii=False)
    print(progress, file=sys.stderr, flush=True)


def _find_env_path() -> str:
    """프로젝트 루트의 .env 파일 경로를 반환한다."""
    here = Path(__file__).parent.parent
    candidate = here / ".env"
    return str(candidate) if candidate.exists() else ".env"


def _load_config_and_db(
    env_path: str,
) -> tuple[Config, str]:
    """Config와 DB 경로를 생성해 반환한다. (config, db_path) 튜플."""
    from news_pulse.blocks.config_loader import EnvConfigLoader
    from news_pulse.db.migrate import migrate

    loader = EnvConfigLoader(env_path=env_path)
    config = loader.load()
    db_path = os.path.expanduser(config.db_path)
    migrate(db_path)
    return config, db_path


def run_manual_trigger() -> None:
    """수동 트리거 — 진행 상황 stderr JSON Line, 결과 stdout JSON."""
    from news_pulse.blocks.config_loader import EnvConfigLoader
    from news_pulse.blocks.model_engine.ollama_engine import OllamaEngine
    from news_pulse.db.store import SqliteStore
    from news_pulse.orchestrator import Pipeline

    env_path = _find_env_path()
    config, db_path = _load_config_and_db(env_path)
    data_dir = str(Path(db_path).parent)

    lock_path = _acquire_lock(data_dir)
    if lock_path is None:
        print(json.dumps({"error": "이미 파이프라인이 실행 중입니다"}), flush=True)
        sys.exit(1)

    try:
        with SqliteStore(db_path) as db:
            loader2 = EnvConfigLoader(env_path=env_path, db=db)
            config = loader2.load()
            ollama = OllamaEngine(config.ollama_endpoint)
            pipeline = Pipeline(config=config, db=db, ollama_engine=ollama)

            # Pipeline.run()을 호출하되 결과를 JSON으로 출력
            result = pipeline.run()
            _emit_progress("complete", 0)
            output = {
                "fetched": result.fetched_count,
                "filtered": result.filtered_count,
                "summarized": result.summarized_count,
                "sent": result.sent_count,
            }
            print(json.dumps(output, ensure_ascii=False), flush=True)
    finally:
        _release_lock(lock_path)


def run_catchup() -> None:
    """놓친 시간대 캐치업 실행."""
    from news_pulse.blocks.config_loader import EnvConfigLoader
    from news_pulse.blocks.skip_detector import detect_missed
    from news_pulse.db.store import SqliteStore
    from news_pulse.orchestrator import Pipeline
    from datetime import datetime

    env_path = _find_env_path()
    config, db_path = _load_config_and_db(env_path)

    with SqliteStore(db_path) as db:
        loader2 = EnvConfigLoader(env_path=env_path, db=db)
        config = loader2.load()
        missed = detect_missed(db, datetime.now())
        if not missed:
            logger.info("누락된 스케줄 없음 — 캐치업 불필요")
            return
        logger.info("캐치업 실행: %d개 누락 시간대", len(missed))
        for slot in missed:
            logger.info("캐치업 실행 중: %s", slot)
            pipeline = Pipeline(config=config, db=db)
            pipeline.run()


def run_digest() -> None:
    """다이제스트 강제 발송 모드."""
    from news_pulse.blocks.config_loader import EnvConfigLoader
    from news_pulse.blocks.telegram_sender import HttpTelegramSender
    from news_pulse.core.digest_pipeline import send_digest
    from news_pulse.db.store import SqliteStore

    env_path = _find_env_path()
    config, db_path = _load_config_and_db(env_path)

    with SqliteStore(db_path) as db:
        loader2 = EnvConfigLoader(env_path=env_path, db=db)
        config = loader2.load()
        sender = HttpTelegramSender(db)
        sent = send_digest(db, config, sender)
        logger.info("다이제스트 강제 발송 완료: %d건", sent)


def run_health_check() -> None:
    """헬스체크 전용 모드 — JSON stdout 출력."""
    from news_pulse.blocks.config_loader import EnvConfigLoader
    from news_pulse.blocks.health_checker import SystemHealthChecker
    from news_pulse.db.store import SqliteStore
    from news_pulse.db.migrate import migrate

    env_path = _find_env_path()
    loader = EnvConfigLoader(env_path=env_path)
    config = loader.load()
    db_path = os.path.expanduser(config.db_path)
    migrate(db_path)

    with SqliteStore(db_path) as db:
        checker = SystemHealthChecker(db)
        report = checker.check(config)

    output = {
        "checked_at": report.checked_at.isoformat(),
        "overall": report.overall,
        "items": [
            {"name": i.name, "status": i.status, "message": i.message}
            for i in report.items
        ],
    }
    print(json.dumps(output, ensure_ascii=False, indent=2))
