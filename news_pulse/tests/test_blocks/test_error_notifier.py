"""
ErrorNotifier 테스트.

텔레그램 알림 전송, DB 저장, 내부 오류 무시 동작을 검증한다.
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from news_pulse.blocks.error_notifier import TelegramErrorNotifier
from news_pulse.models.config import Config


def _config() -> Config:
    """테스트용 Config 객체를 생성한다."""
    return Config(
        bot_token="test_token", admin_chat_id="12345",
        db_path="/tmp/notifier.db", ollama_endpoint="http://localhost:11434",
        apex_model_name="apex", kanana_model_name="kanana",
        memory_threshold_gb=26.0,
    )


def test_notify_텔레그램_전송_호출() -> None:
    """notify() 시 Telegram API가 호출되어야 한다."""
    db = MagicMock()
    db.insert_error.return_value = None
    notifier = TelegramErrorNotifier(db)
    exc = RuntimeError("테스트 에러")
    ctx = {"module": "Pipeline"}

    with patch("news_pulse.blocks.error_notifier.httpx.post") as mock_post:
        mock_post.return_value = MagicMock(status_code=200)
        notifier.notify(exc, ctx, _config())

    mock_post.assert_called_once()
    call_kwargs = mock_post.call_args
    assert "12345" in str(call_kwargs)


def test_notify_DB_에러_저장() -> None:
    """notify() 시 error_log 테이블에 에러가 저장되어야 한다."""
    db = MagicMock()
    db.insert_error.return_value = None
    notifier = TelegramErrorNotifier(db)
    exc = ValueError("유효하지 않은 값")
    ctx = {"module": "Fetcher", "severity": "CRITICAL"}

    with patch("news_pulse.blocks.error_notifier.httpx.post"):
        notifier.notify(exc, ctx, _config())

    db.insert_error.assert_called_once()
    saved = db.insert_error.call_args[0][0]
    assert saved["severity"] == "CRITICAL"
    assert saved["module"] == "Fetcher"


def test_notify_텔레그램_실패시_무시() -> None:
    """텔레그램 전송 실패 시 예외가 전파되지 않아야 한다."""
    db = MagicMock()
    db.insert_error.return_value = None
    notifier = TelegramErrorNotifier(db)
    exc = RuntimeError("에러")
    ctx = {"module": "Test"}

    with patch("news_pulse.blocks.error_notifier.httpx.post", side_effect=ConnectionError):
        # 예외 없이 완료되어야 한다
        notifier.notify(exc, ctx, _config())

    # DB 저장은 여전히 시도되어야 한다
    db.insert_error.assert_called_once()


def test_notify_DB_실패시_무시() -> None:
    """DB 저장 실패 시 예외가 전파되지 않아야 한다."""
    db = MagicMock()
    db.insert_error.side_effect = RuntimeError("DB 연결 실패")
    notifier = TelegramErrorNotifier(db)
    exc = RuntimeError("원래 에러")
    ctx = {"module": "Test"}

    with patch("news_pulse.blocks.error_notifier.httpx.post"):
        # 예외 없이 완료되어야 한다
        notifier.notify(exc, ctx, _config())


def test_notify_context_module_없으면_unknown() -> None:
    """context에 module 키가 없으면 'unknown'을 사용해야 한다."""
    db = MagicMock()
    db.insert_error.return_value = None
    notifier = TelegramErrorNotifier(db)
    exc = RuntimeError("에러")
    ctx: dict[str, object] = {}

    with patch("news_pulse.blocks.error_notifier.httpx.post"):
        notifier.notify(exc, ctx, _config())

    saved = db.insert_error.call_args[0][0]
    assert saved["module"] == "unknown"
