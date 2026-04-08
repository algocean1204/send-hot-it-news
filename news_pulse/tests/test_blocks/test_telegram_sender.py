"""
TelegramSender 단위 테스트.

429 retry 로직, 전송 성공/실패 집계를 검증한다.
"""
from __future__ import annotations

from unittest.mock import MagicMock, call, patch

import pytest

from news_pulse.blocks.telegram_sender import HttpTelegramSender
from news_pulse.models.config import Config


def _make_config() -> Config:
    return Config(
        bot_token="testtoken",
        admin_chat_id="admin123",
        db_path="/tmp/test.db",
        ollama_endpoint="http://localhost:11434",
        apex_model_name="apex",
        kanana_model_name="kanana",
        memory_threshold_gb=26.0,
    )


def test_send_success() -> None:
    """전송 성공 시 success_count가 1 증가해야 한다."""
    mock_db = MagicMock()
    mock_db.get_approved_chat_ids.return_value = []
    sender = HttpTelegramSender(mock_db)

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.raise_for_status = MagicMock()

    with patch("news_pulse.blocks.telegram_sender.httpx.post", return_value=mock_resp):
        result = sender.send("테스트 메시지", _make_config())

    assert result.success_count == 1  # 관리자만
    assert result.failed_chat_ids == []


def test_send_to_approved_subscribers() -> None:
    """승인된 구독자에게도 메시지가 전송되어야 한다."""
    mock_db = MagicMock()
    mock_db.get_approved_chat_ids.return_value = [111, 222]
    sender = HttpTelegramSender(mock_db)

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.raise_for_status = MagicMock()

    with patch("news_pulse.blocks.telegram_sender.httpx.post", return_value=mock_resp):
        result = sender.send("메시지", _make_config())

    # 관리자(1) + 구독자(2) = 3명
    assert result.total == 3
    assert result.success_count == 3


def test_429_triggers_retry() -> None:
    """429 응답 시 재시도가 발생해야 한다."""
    mock_db = MagicMock()
    mock_db.get_approved_chat_ids.return_value = []
    sender = HttpTelegramSender(mock_db)

    # 첫 호출: 429, 두 번째 호출: 200 성공
    resp_429 = MagicMock()
    resp_429.status_code = 429
    resp_429.json.return_value = {"parameters": {"retry_after": 0}}

    resp_200 = MagicMock()
    resp_200.status_code = 200
    resp_200.raise_for_status = MagicMock()

    with patch(
        "news_pulse.blocks.telegram_sender.httpx.post", side_effect=[resp_429, resp_200]
    ), patch("news_pulse.blocks.telegram_sender.time.sleep"):
        result = sender.send("메시지", _make_config())

    assert result.success_count == 1


def test_all_retries_exhausted_marks_failure() -> None:
    """최대 재시도 후에도 실패하면 failed_chat_ids에 기록되어야 한다."""
    mock_db = MagicMock()
    mock_db.get_approved_chat_ids.return_value = []
    sender = HttpTelegramSender(mock_db)

    with patch(
        "news_pulse.blocks.telegram_sender.httpx.post",
        side_effect=ConnectionError("연결 실패"),
    ), patch("news_pulse.blocks.telegram_sender.time.sleep"):
        result = sender.send("메시지", _make_config())

    assert result.success_count == 0
    assert "admin123" in result.failed_chat_ids
