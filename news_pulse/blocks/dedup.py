"""
블럭 5 — Dedup (SqliteDedup).

URL 해시로 중복 아이템을 제거하고, 신규 아이템만 NewsItem으로 변환한다.
신규 항목은 processed_items 테이블에 즉시 삽입해 다음 실행에서도 중복 방지한다.
"""
from __future__ import annotations

import logging
from typing import Protocol

from news_pulse.db.store import SqliteStore
from news_pulse.models.news import NewsItem, RawItem

logger = logging.getLogger(__name__)


class DedupProtocol(Protocol):
    """Dedup 인터페이스 정의."""

    def filter_new(self, items: list[RawItem]) -> list[NewsItem]: ...


class SqliteDedup:
    """SQLite url_hash 조회로 중복을 제거하는 구현체."""

    def __init__(self, db: SqliteStore) -> None:
        """db: url_hash 조회 + 신규 항목 삽입용 SqliteStore."""
        self._db = db

    def filter_new(self, items: list[RawItem]) -> list[NewsItem]:
        """
        중복이 아닌 RawItem만 NewsItem으로 변환해 반환한다.

        DB 접근 실패 시 전체 아이템을 신규로 간주해 파이프라인을 계속 진행한다.
        """
        try:
            return self._do_filter(items)
        except Exception as exc:
            logger.warning("Dedup DB 실패, 전체를 신규로 처리: %s", exc)
            return [self._to_news_item(item) for item in items]

    def _do_filter(self, items: list[RawItem]) -> list[NewsItem]:
        """DB에서 url_hash를 확인하고 신규 항목만 추려낸다."""
        new_items: list[NewsItem] = []
        for raw in items:
            if self._db.url_hash_exists(raw.url_hash):
                continue
            news_item = self._to_news_item(raw)
            # 삽입 후 반환된 DB row id를 NewsItem에 할당한다
            news_item.db_id = self._insert_to_db(raw)
            new_items.append(news_item)
        return new_items

    def _to_news_item(self, raw: RawItem) -> NewsItem:
        """RawItem을 NewsItem으로 변환한다. lang은 이 단계에서 빈 문자열로 초기화."""
        return NewsItem(
            url=raw.url,
            title=raw.title,
            content=raw.content,
            source_id=raw.source_id,
            fetched_at=raw.fetched_at,
            upvotes=raw.upvotes,
            published_at=raw.published_at,
            url_hash=raw.url_hash,
            lang="",
        )

    def _insert_to_db(self, raw: RawItem) -> int:
        """신규 항목을 processed_items에 삽입하고 row id를 반환한다."""
        return self._db.insert_processed_item({
            "url_hash": raw.url_hash,
            "url": raw.url,
            "title": raw.title,
            "source": raw.source_id,
            "language": "",
            "raw_content": raw.content,
            "summary_ko": None,
            "tags": None,
            "upvotes": raw.upvotes,
            "is_hot": 0,
            "pipeline_path": None,
            "processing_time_ms": None,
            "telegram_sent": 0,
        })
