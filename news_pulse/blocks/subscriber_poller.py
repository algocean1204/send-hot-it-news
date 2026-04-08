"""
블럭 3 — SubscriberPoller.

Telegram Bot API getUpdates를 호출해 신규 /start 명령어를 처리하고
구독자를 DB에 upsert한다.
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import Protocol

import httpx

from news_pulse.db.store import SqliteStore
from news_pulse.models.config import Config
from news_pulse.models.telegram import SubscriberEvent

logger = logging.getLogger(__name__)

# Telegram API 기본 URL 템플릿
_TG_API_BASE = "https://api.telegram.org/bot{token}"
# 마지막으로 처리한 offset을 저장하는 filter_config 키
_OFFSET_KEY = "telegram_update_offset"


class SubscriberPollerProtocol(Protocol):
    """SubscriberPoller 인터페이스 정의."""

    def poll(self, config: Config) -> list[SubscriberEvent]: ...


class TelegramSubscriberPoller:
    """Telegram getUpdates를 호출해 구독 이벤트를 처리하는 구현체."""

    def __init__(self, db: SqliteStore) -> None:
        """db: 구독자 upsert + offset 저장용 SqliteStore."""
        self._db = db

    def poll(self, config: Config) -> list[SubscriberEvent]:
        """
        /start 명령어를 감지해 구독자를 DB에 upsert한다.

        API 호출 실패 시 빈 리스트를 반환해 파이프라인을 계속 진행한다.
        """
        try:
            return self._do_poll(config)
        except Exception as exc:
            logger.warning("SubscriberPoller 실패, 건너뜀: %s", exc)
            return []

    def _do_poll(self, config: Config) -> list[SubscriberEvent]:
        """실제 API 호출 및 이벤트 처리 로직."""
        base = _TG_API_BASE.format(token=config.bot_token)
        offset = self._load_offset()
        params: dict[str, object] = {"timeout": 0, "allowed_updates": ["message"]}
        if offset is not None:
            params["offset"] = offset

        resp = httpx.get(f"{base}/getUpdates", params=params, timeout=10)
        resp.raise_for_status()
        # HTTP 200이어도 ok:false면 Telegram API 레벨 오류 — 명시적 검사 필요
        data = resp.json()
        if not data.get("ok"):
            raise RuntimeError(f"Telegram API 오류: {data.get('description', '알 수 없음')}")
        updates: list[dict[str, object]] = data.get("result", [])

        events: list[SubscriberEvent] = []
        max_update_id: int | None = None
        for update in updates:
            # update_id는 항상 정수형이지만 dict value는 object 타입이므로 명시적 변환
            update_id = int(str(update["update_id"]))
            if max_update_id is None or update_id > max_update_id:
                max_update_id = update_id
            event = self._process_update(update, update_id)
            if event is not None:
                events.append(event)

        if max_update_id is not None:
            self._save_offset(max_update_id + 1)
        return events

    def _process_update(
        self, update: dict[str, object], update_id: int
    ) -> SubscriberEvent | None:
        """update에서 /start 명령어를 감지하고 SubscriberEvent를 생성한다."""
        message = update.get("message")
        if not isinstance(message, dict):
            return None
        text = str(message.get("text", ""))
        if not text.startswith("/start"):
            return None

        # message는 dict[str, object]이므로 chat을 명시적으로 타입 좁히기
        raw_chat = message.get("chat", {})
        chat: dict[str, object] = raw_chat if isinstance(raw_chat, dict) else {}
        chat_id = str(chat.get("id", ""))
        # username, first_name은 str 또는 None — 안전하게 문자열로 캐스팅
        raw_username = chat.get("username")
        raw_first_name = chat.get("first_name")
        username: str | None = str(raw_username) if raw_username is not None else None
        first_name: str | None = str(raw_first_name) if raw_first_name is not None else None

        self._db.upsert_subscriber(int(chat_id), username, first_name)
        return SubscriberEvent(
            chat_id=chat_id,
            username=username,
            event_type="subscribe",
            occurred_at=datetime.now(),
            update_id=update_id,
        )

    def _load_offset(self) -> int | None:
        """filter_config에서 마지막 offset을 읽는다."""
        raw = self._db.get_config_value(_OFFSET_KEY)
        return int(raw) if raw is not None else None

    def _save_offset(self, offset: int) -> None:
        """다음 호출을 위해 offset을 filter_config에 저장한다."""
        self._db.set_config_value(_OFFSET_KEY, str(offset))
