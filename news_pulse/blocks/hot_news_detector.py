"""
블럭 11 — HotNewsDetector.

업보트 기준 또는 소스 기반으로 핫뉴스를 판단하고
DB에 저장한다. DB 저장 실패 시 판단 결과는 반환한다.
"""
from __future__ import annotations

import logging
from typing import Protocol

from news_pulse.db.store import SqliteStore
from news_pulse.models.config import Config
from news_pulse.models.news import NewsItem, SummaryResult

logger = logging.getLogger(__name__)

# Tier 1 소스 — AI랩 공식 발표 소스 (자동 핫뉴스 후보)
_TIER1_SOURCES = frozenset({
    "anthropic", "openai", "deepmind", "huggingface",
    "claude_code_releases", "cline_releases", "cursor_changelog",
})

# 핫뉴스 핵심 키워드 — Tier 1 소스와 함께 매칭
_HOT_KEYWORDS = frozenset({
    "release", "launch", "announce", "gpt", "claude", "gemini",
    "breakthrough", "sota", "model", "출시", "발표", "공개",
})


class HotNewsDetectorProtocol(Protocol):
    """HotNewsDetector 인터페이스 정의."""

    def detect(self, item: NewsItem, result: SummaryResult, config: Config) -> bool: ...


class ThresholdHotNewsDetector:
    """업보트 임계값 + 소스 기반으로 핫뉴스를 판단하는 구현체."""

    def __init__(self, db: SqliteStore) -> None:
        """db: processed_items UPDATE + hot_news INSERT용 SqliteStore."""
        self._db = db

    def detect(self, item: NewsItem, result: SummaryResult, config: Config) -> bool:
        """핫뉴스 여부를 판단하고 결과를 DB에 저장한다."""
        is_hot = self._is_hot(item, config)
        if is_hot:
            self._save_hot(item, result)
        return is_hot

    def _is_hot(self, item: NewsItem, config: Config) -> bool:
        """업보트 또는 소스+키워드 기준으로 핫뉴스 여부를 결정한다."""
        if self._by_upvotes(item, config):
            return True
        return self._by_source_and_keyword(item)

    def _by_upvotes(self, item: NewsItem, config: Config) -> bool:
        """HN >= hot_hn_threshold 또는 Reddit >= hot_reddit_threshold면 핫뉴스."""
        if item.upvotes is None:
            return False
        if item.source_id == "hackernews":
            return item.upvotes >= config.hot_hn_threshold
        if "reddit" in item.source_id:
            return item.upvotes >= config.hot_reddit_threshold
        return False

    def _by_source_and_keyword(self, item: NewsItem) -> bool:
        """Tier 1 소스 + 핵심 키워드 매칭 시 핫뉴스로 판단한다."""
        if item.source_id not in _TIER1_SOURCES:
            return False
        text = (item.title + " " + (item.content or "")).lower()
        return any(kw in text for kw in _HOT_KEYWORDS)

    def _save_hot(self, item: NewsItem, result: SummaryResult) -> None:
        """processed_items를 is_hot=1로 갱신하고 hot_news 테이블에 삽입한다."""
        try:
            # processed_items.is_hot 플래그를 1로 갱신한다
            if item.db_id is not None:
                self._db.update_processed_item(item.db_id, {"is_hot": 1})
            self._db.insert_hot_news({
                "processed_item_id": item.db_id,
                "url": item.url,
                "title": item.title,
                "source": item.source_id,
                "summary_ko": result.summary_text,
                "tags": None,
                "upvotes": item.upvotes,
                "hot_reason": self._build_reason(item),
            })
        except Exception as exc:
            logger.warning("핫뉴스 DB 저장 실패 (판단 결과는 유지): %s", exc)

    def _build_reason(self, item: NewsItem) -> str:
        """핫뉴스 선정 이유를 문자열로 생성한다."""
        if item.upvotes and item.upvotes > 0:
            return f"업보트: {item.upvotes}"
        return f"AI랩 공식 발표: {item.source_id}"
