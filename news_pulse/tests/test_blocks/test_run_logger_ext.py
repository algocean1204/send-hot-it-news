"""
RunLogger 확장 테스트.

컬럼 매핑 정확성, status 값 분기, DB 저장 실패 시 stderr 폴백을 검증한다.
"""
from __future__ import annotations

import sys
from datetime import datetime
from io import StringIO
from unittest.mock import MagicMock

import pytest

from news_pulse.blocks.run_logger import SqliteRunLogger
from news_pulse.models.pipeline import PipelineResult


def _result(
    has_error: bool = False,
    error_summary: str | None = None,
    memory_status: str = "local_llm",
) -> PipelineResult:
    """테스트용 PipelineResult를 생성한다."""
    return PipelineResult(
        run_at=datetime(2026, 4, 8, 10, 0, 0),
        fetched_count=20,
        dedup_count=15,
        filtered_count=8,
        summarized_count=8,
        sent_count=8,
        elapsed_seconds=12.345,
        memory_status=memory_status,
        has_error=has_error,
        error_summary=error_summary,
    )


def test_status_success_매핑() -> None:
    """has_error=False일 때 status가 'success'로 저장되어야 한다."""
    db = MagicMock()
    db.insert_run.return_value = 1
    db.update_run.return_value = None

    logger = SqliteRunLogger(db)
    logger.log(_result(has_error=False))

    insert_call = db.insert_run.call_args[0][0]
    assert insert_call["status"] == "success"


def test_status_failure_매핑() -> None:
    """has_error=True일 때 status가 'failure'로 저장되어야 한다."""
    db = MagicMock()
    db.insert_run.return_value = 1
    db.update_run.return_value = None

    logger = SqliteRunLogger(db)
    logger.log(_result(has_error=True, error_summary="에러 발생"))

    insert_call = db.insert_run.call_args[0][0]
    assert insert_call["status"] == "failure"


def test_total_duration_ms_변환() -> None:
    """elapsed_seconds가 total_duration_ms(int)로 변환되어야 한다."""
    db = MagicMock()
    db.insert_run.return_value = 1
    db.update_run.return_value = None

    logger = SqliteRunLogger(db)
    logger.log(_result())

    update_call = db.update_run.call_args[0][1]
    assert update_call["total_duration_ms"] == 12345
    assert isinstance(update_call["total_duration_ms"], int)


def test_error_message_컬럼명_매핑() -> None:
    """error_summary가 error_message 컬럼으로 매핑되어야 한다."""
    db = MagicMock()
    db.insert_run.return_value = 1
    db.update_run.return_value = None

    logger = SqliteRunLogger(db)
    logger.log(_result(has_error=True, error_summary="DB 오류"))

    update_call = db.update_run.call_args[0][1]
    assert update_call["error_message"] == "DB 오류"
    assert "error_summary" not in update_call


def test_memory_mode_전달() -> None:
    """memory_status가 insert_run의 memory_mode로 전달되어야 한다."""
    db = MagicMock()
    db.insert_run.return_value = 1
    db.update_run.return_value = None

    logger = SqliteRunLogger(db)
    logger.log(_result(memory_status="claude_fallback"))

    insert_call = db.insert_run.call_args[0][0]
    assert insert_call["memory_mode"] == "claude_fallback"


def test_DB_저장_실패시_stderr_출력() -> None:
    """DB 저장 실패 시 stderr로 결과가 출력되어야 한다."""
    db = MagicMock()
    db.insert_run.side_effect = RuntimeError("DB 연결 실패")

    logger = SqliteRunLogger(db)
    captured = StringIO()

    old_stderr = sys.stderr
    sys.stderr = captured
    try:
        logger.log(_result())
    finally:
        sys.stderr = old_stderr

    output = captured.getvalue()
    assert "[RunLogger]" in output
    assert "저장 실패" in output
