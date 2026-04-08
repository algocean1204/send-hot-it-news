"""
필터 체인 확장 테스트.

BlacklistFilter 내부 예외 무시, TierRouter 미등록 소스 처리,
PrioritySelector Tier1+2 오버플로우, Tier3 정렬을 검증한다.
"""
from __future__ import annotations

import hashlib
from datetime import datetime

import pytest

from news_pulse.blocks.filter.blacklist_filter import BlacklistFilter
from news_pulse.blocks.filter.priority_selector import PrioritySelector
from news_pulse.blocks.filter.tier_router import TierRouter
from news_pulse.models.config import Config, SourceConfig
from news_pulse.models.news import NewsItem


def _config() -> Config:
    """기본 테스트 Config를 생성한다."""
    return Config(
        bot_token="tok", admin_chat_id="admin",
        db_path="/tmp/filter.db", ollama_endpoint="http://localhost:11434",
        apex_model_name="apex", kanana_model_name="kanana",
        memory_threshold_gb=26.0, sources=[
            SourceConfig("hackernews", "HN", "url", "algolia", 3, "en", True),
            SourceConfig("geeknews", "GeekNews", "url", "rss", 2, "ko", True),
            SourceConfig("anthropic", "Anthropic", "url", "rss", 1, "en", True),
        ],
    )


def _news(
    source_id: str = "hackernews",
    upvotes: int | None = 100,
    title: str = "Test",
    url_suffix: str = "1",
) -> NewsItem:
    """테스트용 NewsItem을 생성한다."""
    url = f"http://test.com/{url_suffix}"
    return NewsItem(
        url=url, title=title, content=None,
        source_id=source_id, fetched_at=datetime.now(),
        upvotes=upvotes, published_at=None,
        url_hash=hashlib.sha256(url.encode()).hexdigest(),
        lang="en",
    )


# -- BlacklistFilter 확장 -- #

def test_blacklist_내용에도_매칭() -> None:
    """제목뿐 아니라 content에 블랙리스트 키워드가 있어도 필터링해야 한다."""
    config = _config()
    config.blacklist_keywords = ["스팸"]
    item = NewsItem(
        url="http://test.com/spam", title="정상 제목",
        content="본문에 스팸 단어 포함", source_id="hackernews",
        fetched_at=datetime.now(), upvotes=50, published_at=None,
        url_hash="hash_spam", lang="en",
    )
    result = BlacklistFilter().apply([item], config)
    assert len(result) == 0


def test_blacklist_여러_키워드_중_하나_매칭() -> None:
    """여러 블랙리스트 키워드 중 하나만 매칭해도 필터링해야 한다."""
    config = _config()
    config.blacklist_keywords = ["광고", "스팸", "프로모션"]
    items = [
        _news(title="일반 뉴스", url_suffix="ok"),
        _news(title="광고 포함 뉴스", url_suffix="ad"),
    ]
    result = BlacklistFilter().apply(items, config)
    assert len(result) == 1
    assert result[0].title == "일반 뉴스"


# -- TierRouter 확장 -- #

def test_tier3_upvotes_None이면_필터링() -> None:
    """Tier 3 소스에서 upvotes가 None이면 필터링되어야 한다."""
    config = _config()
    items = [_news(source_id="hackernews", upvotes=None)]
    result = TierRouter().apply(items, config)
    assert len(result) == 0


def test_tier2_소스_항상_통과() -> None:
    """Tier 2 소스(geeknews)는 업보트와 관계없이 항상 통과해야 한다."""
    config = _config()
    items = [_news(source_id="geeknews", upvotes=None)]
    result = TierRouter().apply(items, config)
    assert len(result) == 1


def test_미등록_소스_tier3_기본값() -> None:
    """config.sources에 없는 소스는 기본 tier 3으로 취급해야 한다."""
    config = _config()
    # 매핑에 없는 소스 — _DEFAULT_TIER_MAP에도 없는 새 소스
    items = [_news(source_id="unknown_source", upvotes=200)]
    result = TierRouter().apply(items, config)
    # upvotes=200이므로 기본 tier3_hn_threshold와 비교해야 한다
    # unknown_source는 "reddit"이 포함되지 않고 "hackernews"도 아니므로 True 반환
    assert len(result) == 1


def test_tier3_hn_임계값_미달() -> None:
    """HN 업보트가 임계값 미만이면 필터링되어야 한다."""
    config = _config()
    config.tier3_hn_threshold = 100
    items = [_news(source_id="hackernews", upvotes=99)]
    result = TierRouter().apply(items, config)
    assert len(result) == 0


def test_tier3_reddit_임계값_경계() -> None:
    """Reddit 업보트가 정확히 임계값이면 통과해야 한다."""
    config = _config()
    config.tier3_reddit_threshold = 25
    items = [_news(source_id="reddit_localllama", upvotes=25)]
    result = TierRouter().apply(items, config)
    assert len(result) == 1


# -- PrioritySelector 확장 -- #

def test_priority_tier1_9개_초과시_전부_반환() -> None:
    """Tier 1이 8개 초과하면 모두 반환해야 한다 (오버플로우 허용)."""
    config = _config()
    items = [
        _news(source_id="anthropic", url_suffix=str(i))
        for i in range(10)
    ]
    result = PrioritySelector().apply(items, config)
    # Tier 1이 10개 → 모두 반환해야 한다
    assert len(result) == 10


def test_priority_tier3_업보트_높은순() -> None:
    """Tier 3는 업보트 높은 순으로 정렬되어야 한다."""
    config = _config()
    items = [
        _news(source_id="hackernews", upvotes=10, url_suffix="low"),
        _news(source_id="hackernews", upvotes=300, url_suffix="high"),
        _news(source_id="hackernews", upvotes=150, url_suffix="mid"),
    ]
    result = PrioritySelector().apply(items, config)
    # 3개 모두 반환 (MAX_ITEMS=8 미만)
    assert len(result) == 3
    # 업보트 높은 순서로 정렬되어야 한다
    assert result[0].upvotes == 300
    assert result[1].upvotes == 150
    assert result[2].upvotes == 10


def test_priority_tier1_tier2_tier3_혼합_8건_선택() -> None:
    """Tier1+2+3 혼합 시 Tier1 > Tier2 > Tier3 순서로 8건 선택해야 한다."""
    config = _config()
    tier1 = [_news(source_id="anthropic", url_suffix=f"t1_{i}") for i in range(3)]
    tier2 = [_news(source_id="geeknews", url_suffix=f"t2_{i}") for i in range(2)]
    tier3 = [
        _news(source_id="hackernews", upvotes=u, url_suffix=f"t3_{u}")
        for u in [200, 100, 50, 10]
    ]
    items = tier1 + tier2 + tier3
    result = PrioritySelector().apply(items, config)

    # 총 9개 중 8건만 선택되어야 한다
    assert len(result) == 8
    # Tier 1 3개 + Tier 2 2개 = 5개가 먼저, 나머지 3개는 Tier 3 상위
    tier3_results = result[5:]
    assert tier3_results[0].upvotes == 200
    assert tier3_results[1].upvotes == 100
    assert tier3_results[2].upvotes == 50
