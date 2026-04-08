"""
HotNewsDetector 단위 테스트.

업보트 임계값 및 소스 기반 핫뉴스 판단을 검증한다.
"""
from __future__ import annotations

from datetime import datetime
from unittest.mock import MagicMock

from news_pulse.blocks.hot_news_detector import ThresholdHotNewsDetector
from news_pulse.models.config import Config
from news_pulse.models.news import NewsItem, SummaryResult


def _make_config(hn_threshold: int = 200, reddit_threshold: int = 80) -> Config:
    return Config(
        bot_token="tok", admin_chat_id="1", db_path="/tmp/test.db",
        ollama_endpoint="http://localhost:11434", apex_model_name="apex",
        kanana_model_name="kanana", memory_threshold_gb=26.0,
        hot_hn_threshold=hn_threshold, hot_reddit_threshold=reddit_threshold,
    )


def _make_item(source_id: str, upvotes: int | None = None, title: str = "뉴스") -> NewsItem:
    return NewsItem(
        url="http://example.com", title=title, content="내용",
        source_id=source_id, fetched_at=datetime.now(), upvotes=upvotes,
        published_at=None, url_hash="abc", lang="en",
    )


def _make_result() -> SummaryResult:
    return SummaryResult(
        item_url="http://example.com", summary_text="요약",
        original_lang="en", summarizer_used="apex", translator_used=None, error=None,
    )


def test_hn_above_threshold_is_hot() -> None:
    """HN 업보트가 임계값 이상이면 핫뉴스여야 한다."""
    mock_db = MagicMock()
    detector = ThresholdHotNewsDetector(mock_db)
    item = _make_item("hackernews", upvotes=250)
    result = detector.detect(item, _make_result(), _make_config(hn_threshold=200))
    assert result is True


def test_hn_below_threshold_not_hot() -> None:
    """HN 업보트가 임계값 미만이면 핫뉴스가 아니어야 한다."""
    mock_db = MagicMock()
    detector = ThresholdHotNewsDetector(mock_db)
    item = _make_item("hackernews", upvotes=100)
    result = detector.detect(item, _make_result(), _make_config(hn_threshold=200))
    assert result is False


def test_reddit_above_threshold_is_hot() -> None:
    """Reddit 업보트가 임계값 이상이면 핫뉴스여야 한다."""
    mock_db = MagicMock()
    detector = ThresholdHotNewsDetector(mock_db)
    item = _make_item("reddit_localllama", upvotes=100)
    result = detector.detect(item, _make_result(), _make_config(reddit_threshold=80))
    assert result is True


def test_tier1_with_keyword_is_hot() -> None:
    """Tier 1 소스 + 핵심 키워드 매칭 시 핫뉴스여야 한다."""
    mock_db = MagicMock()
    detector = ThresholdHotNewsDetector(mock_db)
    item = _make_item("anthropic", title="Claude 3 release announcement")
    result = detector.detect(item, _make_result(), _make_config())
    assert result is True


def test_db_failure_does_not_affect_result() -> None:
    """DB 저장 실패해도 판단 결과는 반환되어야 한다."""
    mock_db = MagicMock()
    mock_db.insert_hot_news.side_effect = RuntimeError("DB 오류")
    detector = ThresholdHotNewsDetector(mock_db)
    item = _make_item("hackernews", upvotes=300)
    # DB 실패에도 True가 반환되어야 한다
    result = detector.detect(item, _make_result(), _make_config(hn_threshold=200))
    assert result is True
