"""
블럭 13 — TelegramSender.

MarkdownV2 메시지를 관리자 + 승인된 구독자에게 전송한다.
429 Too Many Requests 시 지수 백오프 재시도 (최대 3회).
"""
from __future__ import annotations

import logging
import time
from typing import Protocol

import httpx

from news_pulse.db.store import SqliteStore
from news_pulse.models.config import Config
from news_pulse.models.telegram import SendResult

logger = logging.getLogger(__name__)

_TG_API_BASE = "https://api.telegram.org/bot{token}/sendMessage"
# 최대 재시도 횟수 (429 에러 시)
_MAX_RETRIES = 3
# 초기 대기 시간 (초) — 지수 백오프
_INITIAL_BACKOFF = 1.0


class TelegramSenderProtocol(Protocol):
    """TelegramSender 인터페이스 정의."""

    def send(self, message: str, config: Config) -> SendResult: ...


class HttpTelegramSender:
    """Telegram Bot API로 메시지를 전송하는 구현체."""

    def __init__(self, db: SqliteStore) -> None:
        """db: approved chat_id 조회용 SqliteStore."""
        self._db = db

    def send(self, message: str, config: Config) -> SendResult:
        """승인된 구독자 + 관리자에게 메시지를 전송한다."""
        chat_ids = self._collect_chat_ids(config)
        total = len(chat_ids)
        success_count = 0
        failed_ids: list[str] = []
        errors: dict[str, str] = {}

        for chat_id in chat_ids:
            err = self._send_to(message, str(chat_id), config.bot_token)
            if err is None:
                success_count += 1
            else:
                failed_ids.append(str(chat_id))
                errors[str(chat_id)] = err
            # Telegram 전역 30msg/sec, 채팅당 1msg/sec 제한을 준수하는 50ms 간격
            time.sleep(0.05)

        return SendResult(
            total=total,
            success_count=success_count,
            failed_chat_ids=failed_ids,
            errors=errors,
        )

    def _collect_chat_ids(self, config: Config) -> list[str]:
        """관리자 + 승인된 구독자 chat_id를 중복 없이 수집한다."""
        ids: set[str] = {config.admin_chat_id}
        try:
            approved = self._db.get_approved_chat_ids()
            ids.update(str(cid) for cid in approved)
        except Exception as exc:
            logger.warning("구독자 목록 조회 실패: %s", exc)
        return list(ids)

    def _send_to(self, message: str, chat_id: str, token: str) -> str | None:
        """단일 chat_id에 메시지를 전송한다. 실패 시 에러 문자열 반환."""
        url = _TG_API_BASE.format(token=token)
        payload = {"chat_id": chat_id, "text": message, "parse_mode": "MarkdownV2"}
        backoff = _INITIAL_BACKOFF
        for attempt in range(_MAX_RETRIES):
            try:
                resp = httpx.post(url, json=payload, timeout=10)
                if resp.status_code == 429:
                    retry_after = resp.json().get("parameters", {}).get("retry_after", backoff)
                    time.sleep(float(retry_after))
                    backoff *= 2
                    continue
                resp.raise_for_status()
                # HTTP 200이어도 ok:false면 API 레벨 오류 — 반드시 확인
                data = resp.json()
                if not data.get("ok"):
                    raise RuntimeError(f"Telegram API 오류: {data.get('description', '알 수 없음')}")
                return None
            except Exception as exc:
                if attempt == _MAX_RETRIES - 1:
                    return str(exc)
                time.sleep(backoff)
                backoff *= 2
        return "최대 재시도 횟수 초과"
