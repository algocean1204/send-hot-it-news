"""
HotNewsDetector 확장 테스트.

소스+키워드 판단, processed_item_id=None 허용,
핫뉴스 이유 문자열 생성, DB 저장 호출을 검증한다.
"""
from __future__ import annotations

import hashlib
from datetime import datetime
from unittest.mock import MagicMock, call

import pytest

from news_pulse.blocks.hot_news_detector import ThresholdHotNewsDetector
from news_pulse.models.config import Config
from news_pulse.models.news import NewsItem, SummaryResult


def _config() -> Config:
    """테스트용 Config 객체를 생성한다."""
    return Config(
        bot_token="tok", admin_chat_id="admin1",
        db_path="/tmp/hot.db", ollama_endpoint="http://localhost:11434",
        apex_model_name="apex", kanana_model_name="kanana",
        memory_threshold_gb=26.0,
    )


def _news(
    source_id: str = "hackernews",
    title: str = "Test",
    upvotes: int | None = None,
    content: str | None = None,
) -> NewsItem:
    """테스트용 NewsItem을 생성한다."""
    url = f"http://test.com/{source_id}/{upvotes}"
    return NewsItem(
        url=url, title=title, content=content,
        source_id=source_id, fetched_at=datetime.now(),
        upvotes=upvotes, published_at=None,
        url_hash=hashlib.sha256(url.encode()).hexdigest(),
        lang="en",
    )


def _summary(url: str = "http://test.com") -> SummaryResult:
    """테스트용 SummaryResult를 생성한다."""
    return SummaryResult(
        item_url=url, summary_text="요약",
        original_lang="en", summarizer_used="apex",
        translator_used=None, error=None,
    )


def test_tier1_키워드_매칭_핫뉴스() -> None:
    """Tier 1 소스 + 핫키워드 매칭 시 핫뉴스로 판단해야 한다."""
    db = MagicMock()
    db.insert_hot_news.return_value = 1
    detector = ThresholdHotNewsDetector(db)
    item = _news(source_id="anthropic", title="Claude 4 release announced")
    result = detector.detect(item, _summary(item.url), _config())
    assert result is True


def test_tier1_키워드_없으면_핫뉴스_아님() -> None:
    """Tier 1 소스이지만 핫키워드가 없으면 핫뉴스가 아니어야 한다."""
    db = MagicMock()
    detector = ThresholdHotNewsDetector(db)
    item = _news(source_id="anthropic", title="A normal blog post")
    result = detector.detect(item, _summary(item.url), _config())
    assert result is False


def test_비_tier1_소스_키워드_있어도_핫뉴스_아님() -> None:
    """Tier 1이 아닌 소스는 키워드가 있어도 소스 기반 핫뉴스가 아니어야 한다."""
    db = MagicMock()
    detector = ThresholdHotNewsDetector(db)
    # geeknews는 Tier 2이므로 _TIER1_SOURCES에 없다
    item = _news(source_id="geeknews", title="Claude release news")
    result = detector.detect(item, _summary(item.url), _config())
    assert result is False


def test_processed_item_id_None_허용() -> None:
    """insert_hot_news 호출 시 processed_item_id=None이 전달되어야 한다."""
    db = MagicMock()
    db.insert_hot_news.return_value = 1
    detector = ThresholdHotNewsDetector(db)
    item = _news(source_id="hackernews", upvotes=300)
    detector.detect(item, _summary(item.url), _config())

    saved = db.insert_hot_news.call_args[0][0]
    assert saved["processed_item_id"] is None


def test_핫뉴스_이유_업보트_포함() -> None:
    """업보트 기반 핫뉴스의 이유에 업보트 수가 포함되어야 한다."""
    db = MagicMock()
    db.insert_hot_news.return_value = 1
    detector = ThresholdHotNewsDetector(db)
    item = _news(source_id="hackernews", upvotes=250)
    detector.detect(item, _summary(item.url), _config())

    saved = db.insert_hot_news.call_args[0][0]
    assert "250" in saved["hot_reason"]


def test_핫뉴스_이유_AI랩_공식_발표() -> None:
    """소스 기반 핫뉴스의 이유에 소스 이름이 포함되어야 한다."""
    db = MagicMock()
    db.insert_hot_news.return_value = 1
    detector = ThresholdHotNewsDetector(db)
    # upvotes=None이므로 업보트 기반이 아닌 소스 기반으로 판단
    item = _news(source_id="openai", title="GPT-5 launch", upvotes=None)
    detector.detect(item, _summary(item.url), _config())

    saved = db.insert_hot_news.call_args[0][0]
    assert "openai" in saved["hot_reason"]


def test_upvotes_None이면_업보트_판단_False() -> None:
    """upvotes가 None이면 업보트 기반 핫뉴스 판단이 False여야 한다."""
    db = MagicMock()
    detector = ThresholdHotNewsDetector(db)
    item = _news(source_id="hackernews", upvotes=None)
    result = detector.detect(item, _summary(item.url), _config())
    assert result is False


def test_reddit_핫뉴스_임계값() -> None:
    """Reddit 소스에서 hot_reddit_threshold(80) 이상이면 핫뉴스여야 한다."""
    db = MagicMock()
    db.insert_hot_news.return_value = 1
    detector = ThresholdHotNewsDetector(db)
    item = _news(source_id="reddit_localllama", upvotes=80)
    result = detector.detect(item, _summary(item.url), _config())
    assert result is True


def test_DB_저장_실패시_판단결과_유지() -> None:
    """DB 저장 실패 시에도 핫뉴스 판단 결과(True)를 반환해야 한다."""
    db = MagicMock()
    db.insert_hot_news.side_effect = RuntimeError("DB 오류")
    detector = ThresholdHotNewsDetector(db)
    item = _news(source_id="hackernews", upvotes=300)
    result = detector.detect(item, _summary(item.url), _config())
    # DB 저장은 실패하지만 판단 결과는 True여야 한다
    assert result is True
