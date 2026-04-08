"""
블럭 15 — ErrorNotifier.

에러 발생 시 관리자에게 텔레그램 알림을 전송하고
error_log 테이블에 기록한다.
무한 재귀 방지를 위해 내부 예외는 무시하고 stderr만 출력한다.
"""
from __future__ import annotations

import logging
import sys
import traceback
from typing import Protocol

import httpx

from news_pulse.db.store import SqliteStore
from news_pulse.models.config import Config

logger = logging.getLogger(__name__)

_TG_SEND_URL = "https://api.telegram.org/bot{token}/sendMessage"


class ErrorNotifierProtocol(Protocol):
    """ErrorNotifier 인터페이스 정의."""

    def notify(self, exc: Exception, context: dict[str, object], config: Config) -> None: ...


class TelegramErrorNotifier:
    """텔레그램 알림 + error_log 저장으로 에러를 처리하는 구현체."""

    def __init__(self, db: SqliteStore) -> None:
        """db: error_log INSERT용 SqliteStore."""
        self._db = db

    def notify(self, exc: Exception, context: dict[str, object], config: Config) -> None:
        """에러 알림 전송과 DB 저장을 수행한다. 내부 오류는 무시한다."""
        module = str(context.get("module", "unknown"))
        message = f"[news-pulse] module={module} error={exc}"

        self._send_telegram(message, config)
        self._save_to_db(exc, module, message, context)

    def _send_telegram(self, message: str, config: Config) -> None:
        """관리자 chat_id에 에러 메시지를 전송한다. 실패 시 stderr만 출력."""
        try:
            url = _TG_SEND_URL.format(token=config.bot_token)
            payload = {"chat_id": config.admin_chat_id, "text": message}
            resp = httpx.post(url, json=payload, timeout=5)
            resp.raise_for_status()
            # HTTP 200이어도 ok:false면 API 레벨 오류 — 무한 재귀 방지를 위해 raise 대신 stderr 출력
            data = resp.json()
            if not data.get("ok"):
                print(
                    f"[ErrorNotifier] Telegram API 오류: {data.get('description', '알 수 없음')}",
                    file=sys.stderr,
                )
        except Exception as send_exc:
            print(f"[ErrorNotifier] 알림 전송 실패: {send_exc}", file=sys.stderr)

    def _save_to_db(
        self, exc: Exception, module: str, message: str, context: dict[str, object]
    ) -> None:
        """error_log 테이블에 에러를 기록한다. DB 실패 시 stderr만 출력."""
        try:
            severity = str(context.get("severity", "ERROR"))
            tb = traceback.format_exc()
            self._db.insert_error({
                "run_id": context.get("run_id"),
                "severity": severity,
                "module": module,
                "message": message,
                "traceback": tb,
            })
        except Exception as db_exc:
            print(f"[ErrorNotifier] DB 저장 실패: {db_exc}", file=sys.stderr)
