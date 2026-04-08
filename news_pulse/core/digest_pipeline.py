"""
다이제스트 파이프라인 원자 모듈.

미전송 아이템을 로드해 다이제스트 포맷으로 묶고 Telegram으로 발송한다.
개별 모드 대신 다이제스트 모드가 활성화된 경우에만 호출된다.
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import Protocol

from news_pulse.blocks.digest_formatter import format_digest
from news_pulse.db.store import SqliteStore
from news_pulse.models.config import Config
from news_pulse.models.news import NewsItem, SummaryResult

logger = logging.getLogger(__name__)


class _Sender(Protocol):
    def send(self, message: str, config: Config) -> object: ...


def _load_unsent_items(store: SqliteStore) -> list[tuple[NewsItem, SummaryResult, bool]]:
    """미전송(telegram_sent=0) 아이템을 오늘 날짜 기준으로 로드한다."""
    today = datetime.now().strftime("%Y-%m-%d")
    rows = store.get_processed_items_by_date(today)
    result: list[tuple[NewsItem, SummaryResult, bool]] = []
    for row in rows:
        if row.get("telegram_sent"):
            continue
        item = NewsItem(
            url=str(row.get("url", "")),
            title=str(row.get("title", "")),
            content=None,
            source_id=str(row.get("source", "")),
            fetched_at=datetime.now(),
            upvotes=None,
            published_at=None,
            url_hash=str(row.get("url_hash", "")),
            lang="ko",
            db_id=int(str(row["id"])) if row.get("id") is not None else None,
        )
        summary = SummaryResult(
            item_url=str(row.get("url", "")),
            summary_text=str(row.get("summary_text", "")) if row.get("summary_text") else "",
            original_lang="ko",
            summarizer_used=str(row.get("summarizer_model", "none")),
            translator_used=None,
            error=None,
        )
        is_hot = bool(row.get("is_hot", 0))
        result.append((item, summary, is_hot))
    return result


def send_digest(store: SqliteStore, config: Config, sender: _Sender) -> int:
    """미전송 아이템을 다이제스트로 묶어 전송하고 전송된 메시지 수를 반환한다."""
    items = _load_unsent_items(store)
    if not items:
        logger.info("다이제스트 전송 대상 아이템 없음")
        return 0
    messages = format_digest(items)
    sent_count = 0
    for msg in messages:
        try:
            sender.send(msg, config)
            sent_count += 1
        except Exception as exc:
            logger.warning("다이제스트 메시지 전송 실패: %s", exc)
    logger.info("다이제스트 전송 완료: %d건", sent_count)
    return sent_count
