"""
블럭 14 — RunLogger.

파이프라인 실행 결과를 run_history 테이블에 기록한다.
DB 저장 실패 시 stderr로 폴백한다.
"""
from __future__ import annotations

import logging
import sys
from typing import Protocol

from news_pulse.db.store import SqliteStore
from news_pulse.models.pipeline import PipelineResult

logger = logging.getLogger(__name__)


class RunLoggerProtocol(Protocol):
    """RunLogger 인터페이스 정의."""

    def log(self, result: PipelineResult) -> None: ...


class SqliteRunLogger:
    """PipelineResult를 run_history 테이블에 기록하는 구현체."""

    def __init__(self, db: SqliteStore) -> None:
        """db: run_history INSERT용 SqliteStore."""
        self._db = db

    def log(self, result: PipelineResult) -> None:
        """실행 결과를 DB에 저장한다. 실패 시 stderr로 출력한다."""
        try:
            self._do_log(result)
        except Exception as exc:
            logger.error("RunLogger DB 저장 실패: %s", exc)
            print(
                f"[RunLogger] 저장 실패 — run_at={result.run_at}, "
                f"fetched={result.fetched_count}, sent={result.sent_count}, "
                f"error={exc}",
                file=sys.stderr,
            )

    def _do_log(self, result: PipelineResult) -> None:
        """run_history에 실행 결과를 삽입한다."""
        # has_error가 True면 failure, 아니면 success — 스키마 enum 일치
        status = "failure" if result.has_error else "success"
        run_id = self._db.insert_run({
            "started_at": result.run_at.isoformat(),
            "status": status,
            "memory_mode": result.memory_status,
        })
        self._db.update_run(run_id, {
            "finished_at": result.run_at.isoformat(),
            "fetched_count": result.fetched_count,
            # dedup_count는 스키마에 없는 컬럼이므로 제거
            "filtered_count": result.filtered_count,
            "summarized_count": result.summarized_count,
            "sent_count": result.sent_count,
            # elapsed_seconds(float) -> total_duration_ms(int)로 변환
            "total_duration_ms": int(result.elapsed_seconds * 1000),
            # error_summary -> error_message (스키마 컬럼명 일치)
            "error_message": result.error_summary,
        })
