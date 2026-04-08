"""
LanguageDetector 단위 테스트.

소스 기반 감지와 기본 언어 반환을 검증한다.
"""
from __future__ import annotations

from datetime import datetime

from news_pulse.blocks.language_detector import ChainedLanguageDetector
from news_pulse.models.news import NewsItem


def _make_item(source_id: str) -> NewsItem:
    """테스트용 NewsItem을 생성한다."""
    return NewsItem(
        url="http://example.com",
        title="Test title",
        content="Test content",
        source_id=source_id,
        fetched_at=datetime.now(),
        upvotes=None,
        published_at=None,
        url_hash="abc123",
        lang="",
    )


def test_geeknews_detected_as_korean() -> None:
    """GeekNews 소스는 한국어로 감지되어야 한다."""
    detector = ChainedLanguageDetector()
    item = _make_item("geeknews")
    result = detector.detect(item)
    assert result.lang == "ko"


def test_hackernews_detected_as_english() -> None:
    """Hacker News 소스는 영어로 감지되어야 한다."""
    detector = ChainedLanguageDetector()
    item = _make_item("hackernews")
    result = detector.detect(item)
    assert result.lang == "en"


def test_reddit_detected_as_english() -> None:
    """Reddit 소스는 영어로 감지되어야 한다."""
    detector = ChainedLanguageDetector()
    item = _make_item("reddit_localllama")
    result = detector.detect(item)
    assert result.lang == "en"


def test_anthropic_detected_as_english() -> None:
    """Anthropic 소스는 영어로 감지되어야 한다."""
    detector = ChainedLanguageDetector()
    item = _make_item("anthropic")
    result = detector.detect(item)
    assert result.lang == "en"


def test_other_fields_preserved() -> None:
    """감지 후에도 다른 필드는 그대로 보존되어야 한다."""
    detector = ChainedLanguageDetector()
    item = _make_item("openai")
    item_with_upvotes = NewsItem(
        url=item.url, title=item.title, content=item.content,
        source_id=item.source_id, fetched_at=item.fetched_at,
        upvotes=100, published_at=None, url_hash=item.url_hash, lang="",
    )
    result = detector.detect(item_with_upvotes)
    assert result.upvotes == 100
    assert result.source_id == "openai"
