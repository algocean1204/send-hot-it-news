"""
SubscriberPoller 테스트.

Telegram getUpdates API 호출, /start 명령어 처리,
offset 저장/로드, API 실패 시 빈 리스트 반환을 검증한다.
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from news_pulse.blocks.subscriber_poller import TelegramSubscriberPoller
from news_pulse.models.config import Config


def _config() -> Config:
    """테스트용 Config 객체를 생성한다."""
    return Config(
        bot_token="test_bot_token", admin_chat_id="admin1",
        db_path="/tmp/poller.db", ollama_endpoint="http://localhost:11434",
        apex_model_name="apex", kanana_model_name="kanana",
        memory_threshold_gb=26.0,
    )


def _mock_update(update_id: int, chat_id: int, text: str) -> dict:
    """Telegram getUpdates 응답의 update 항목을 생성한다."""
    return {
        "update_id": update_id,
        "message": {
            "text": text,
            "chat": {
                "id": chat_id,
                "username": "testuser",
                "first_name": "Test",
            },
        },
    }


def test_start_명령어_구독자_upsert() -> None:
    """/start 명령어 수신 시 구독자가 DB에 upsert되어야 한다."""
    db = MagicMock()
    db.get_config_value.return_value = None
    db.upsert_subscriber.return_value = None
    db.set_config_value.return_value = None
    poller = TelegramSubscriberPoller(db)

    resp = MagicMock()
    resp.status_code = 200
    # ok:true가 없으면 Telegram API 오류로 간주한다
    resp.json.return_value = {
        "ok": True,
        "result": [_mock_update(100, 12345, "/start")],
    }

    with patch("news_pulse.blocks.subscriber_poller.httpx.get", return_value=resp):
        events = poller.poll(_config())

    assert len(events) == 1
    assert events[0].chat_id == "12345"
    assert events[0].event_type == "subscribe"
    db.upsert_subscriber.assert_called_once_with(12345, "testuser", "Test")


def test_start_아닌_메시지_무시() -> None:
    """/start가 아닌 메시지는 무시되어야 한다."""
    db = MagicMock()
    db.get_config_value.return_value = None
    db.set_config_value.return_value = None
    poller = TelegramSubscriberPoller(db)

    resp = MagicMock()
    resp.status_code = 200
    resp.json.return_value = {
        "ok": True,
        "result": [_mock_update(101, 12345, "/help")],
    }

    with patch("news_pulse.blocks.subscriber_poller.httpx.get", return_value=resp):
        events = poller.poll(_config())

    assert len(events) == 0
    db.upsert_subscriber.assert_not_called()


def test_offset_저장() -> None:
    """처리 후 max_update_id + 1이 offset으로 저장되어야 한다."""
    db = MagicMock()
    db.get_config_value.return_value = None
    db.upsert_subscriber.return_value = None
    db.set_config_value.return_value = None
    poller = TelegramSubscriberPoller(db)

    resp = MagicMock()
    resp.status_code = 200
    resp.json.return_value = {
        "ok": True,
        "result": [
            _mock_update(200, 111, "/start"),
            _mock_update(201, 222, "/start"),
        ],
    }

    with patch("news_pulse.blocks.subscriber_poller.httpx.get", return_value=resp):
        poller.poll(_config())

    # max_update_id=201이므로 202가 저장되어야 한다
    db.set_config_value.assert_called_once_with(
        "telegram_update_offset", "202"
    )


def test_API_실패시_빈_리스트() -> None:
    """getUpdates API 호출 실패 시 빈 리스트를 반환해야 한다."""
    db = MagicMock()
    db.get_config_value.return_value = None
    poller = TelegramSubscriberPoller(db)

    with patch(
        "news_pulse.blocks.subscriber_poller.httpx.get",
        side_effect=ConnectionError("네트워크 오류"),
    ):
        events = poller.poll(_config())

    assert events == []


def test_빈_업데이트_결과() -> None:
    """업데이트가 없으면 빈 리스트를 반환하고 offset을 변경하지 않아야 한다."""
    db = MagicMock()
    db.get_config_value.return_value = "50"
    poller = TelegramSubscriberPoller(db)

    resp = MagicMock()
    resp.status_code = 200
    resp.json.return_value = {"ok": True, "result": []}

    with patch("news_pulse.blocks.subscriber_poller.httpx.get", return_value=resp):
        events = poller.poll(_config())

    assert events == []
    db.set_config_value.assert_not_called()


def test_message_아닌_업데이트_무시() -> None:
    """message가 dict가 아닌 업데이트는 무시되어야 한다."""
    db = MagicMock()
    db.get_config_value.return_value = None
    db.set_config_value.return_value = None
    poller = TelegramSubscriberPoller(db)

    resp = MagicMock()
    resp.status_code = 200
    resp.json.return_value = {
        "ok": True,
        "result": [{"update_id": 300, "message": "not_a_dict"}],
    }

    with patch("news_pulse.blocks.subscriber_poller.httpx.get", return_value=resp):
        events = poller.poll(_config())

    assert events == []
