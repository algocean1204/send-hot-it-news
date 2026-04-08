"""
Filter 단위 테스트.

Tier별 할당량 동작, 블랙리스트 필터링을 검증한다.
"""
from __future__ import annotations

from datetime import datetime

import pytest

from news_pulse.blocks.filter.blacklist_filter import BlacklistFilter
from news_pulse.blocks.filter.priority_selector import PrioritySelector
from news_pulse.blocks.filter.tier_router import TierRouter
from news_pulse.models.config import Config, SourceConfig
from news_pulse.models.news import NewsItem


def _make_config(
    blacklist: list[str] | None = None,
    hn_threshold: int = 50,
    reddit_threshold: int = 25,
) -> Config:
    """테스트용 Config를 생성한다."""
    return Config(
        bot_token="tok",
        admin_chat_id="1",
        db_path="/tmp/test.db",
        ollama_endpoint="http://localhost:11434",
        apex_model_name="apex",
        kanana_model_name="kanana",
        memory_threshold_gb=26.0,
        blacklist_keywords=blacklist or [],
        tier3_hn_threshold=hn_threshold,
        tier3_reddit_threshold=reddit_threshold,
    )


def _make_item(source_id: str, title: str = "뉴스", upvotes: int | None = None) -> NewsItem:
    """테스트용 NewsItem을 생성한다."""
    return NewsItem(
        url=f"http://example.com/{source_id}",
        title=title,
        content="내용",
        source_id=source_id,
        fetched_at=datetime.now(),
        upvotes=upvotes,
        published_at=None,
        url_hash=f"hash_{source_id}",
        lang="en",
    )


class TestBlacklistFilter:
    def test_removes_blacklisted_items(self) -> None:
        """블랙리스트 키워드가 포함된 아이템은 제거되어야 한다."""
        config = _make_config(blacklist=["crypto", "NFT"])
        items = [_make_item("test", title="crypto news"), _make_item("test", title="AI 뉴스")]
        result = BlacklistFilter().apply(items, config)
        assert len(result) == 1
        assert result[0].title == "AI 뉴스"

    def test_empty_blacklist_returns_all(self) -> None:
        """블랙리스트가 비어있으면 모든 아이템을 반환해야 한다."""
        config = _make_config(blacklist=[])
        items = [_make_item("test", title="crypto"), _make_item("test", title="AI")]
        result = BlacklistFilter().apply(items, config)
        assert len(result) == 2

    def test_case_insensitive_matching(self) -> None:
        """블랙리스트 매칭은 대소문자를 구분하지 않아야 한다."""
        config = _make_config(blacklist=["CRYPTO"])
        items = [_make_item("test", title="crypto news")]
        result = BlacklistFilter().apply(items, config)
        assert result == []


class TestTierRouter:
    def test_tier1_passes_always(self) -> None:
        """Tier 1 소스는 항상 통과해야 한다."""
        config = _make_config()
        items = [_make_item("anthropic"), _make_item("openai")]
        result = TierRouter().apply(items, config)
        assert len(result) == 2

    def test_tier3_hn_below_threshold_filtered(self) -> None:
        """HN 업보트가 임계값 미만이면 제거되어야 한다."""
        config = _make_config(hn_threshold=50)
        items = [_make_item("hackernews", upvotes=30)]
        result = TierRouter().apply(items, config)
        assert result == []

    def test_tier3_hn_above_threshold_passes(self) -> None:
        """HN 업보트가 임계값 이상이면 통과해야 한다."""
        config = _make_config(hn_threshold=50)
        items = [_make_item("hackernews", upvotes=100)]
        result = TierRouter().apply(items, config)
        assert len(result) == 1

    def test_tier3_reddit_threshold(self) -> None:
        """Reddit 업보트 임계값이 정확히 적용되어야 한다."""
        config = _make_config(reddit_threshold=25)
        below = _make_item("reddit_localllama", upvotes=20)
        above = _make_item("reddit_claudeai", upvotes=30)
        result = TierRouter().apply([below, above], config)
        assert len(result) == 1
        assert result[0].source_id == "reddit_claudeai"


class TestPrioritySelector:
    def test_max_eight_items_returned(self) -> None:
        """최대 8건이 반환되어야 한다."""
        config = _make_config()
        items = [_make_item("hackernews", upvotes=100)] * 15
        result = PrioritySelector().apply(items, config)
        assert len(result) <= 8

    def test_tier1_prioritized_over_tier3(self) -> None:
        """Tier 1 아이템이 Tier 3보다 우선 선택되어야 한다."""
        config = _make_config()
        tier1_items = [_make_item("anthropic")] * 3
        tier3_items = [_make_item("hackernews", upvotes=500)] * 10
        result = PrioritySelector().apply(tier1_items + tier3_items, config)
        tier1_in_result = [i for i in result if i.source_id == "anthropic"]
        assert len(tier1_in_result) == 3

    def test_tier1_overflow_allowed(self) -> None:
        """Tier 1+2가 8건 초과 시 모두 허용되어야 한다."""
        config = _make_config()
        tier1_items = [_make_item("anthropic")] * 10
        result = PrioritySelector().apply(tier1_items, config)
        assert len(result) == 10
