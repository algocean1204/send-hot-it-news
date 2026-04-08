"""
LanguageDetector 확장 테스트.

LinguaDetector 동작, ChainedLanguageDetector 체인 흐름,
lingua 라이브러리 실패 시 기본값 반환을 검증한다.
"""
from __future__ import annotations

import hashlib
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest

from news_pulse.blocks.language_detector import (
    ChainedLanguageDetector,
    LinguaDetector,
    SourceFirstDetector,
)
from news_pulse.models.news import NewsItem


def _news(
    source_id: str = "hackernews",
    title: str = "Test article",
    content: str | None = "Some content",
) -> NewsItem:
    """테스트용 NewsItem을 생성한다."""
    url = f"http://test.com/{source_id}"
    return NewsItem(
        url=url, title=title, content=content,
        source_id=source_id, fetched_at=datetime.now(),
        upvotes=50, published_at=None,
        url_hash=hashlib.sha256(url.encode()).hexdigest(),
        lang="",
    )


def test_SourceFirst_한국어_소스() -> None:
    """geeknews 소스는 항상 'ko'로 판단해야 한다."""
    detector = SourceFirstDetector()
    result = detector.detect(_news(source_id="geeknews"))
    assert result.lang == "ko"


def test_SourceFirst_영어_소스() -> None:
    """geeknews가 아닌 소스는 항상 'en'으로 판단해야 한다."""
    detector = SourceFirstDetector()
    for src in ["hackernews", "reddit_localllama", "anthropic", "openai"]:
        result = detector.detect(_news(source_id=src))
        assert result.lang == "en", f"{src}가 'en'이어야 한다"


def test_SourceFirst_필드_보존() -> None:
    """감지 후 다른 필드가 보존되어야 한다."""
    detector = SourceFirstDetector()
    item = _news(title="원본 제목", content="원본 내용")
    result = detector.detect(item)
    assert result.title == "원본 제목"
    assert result.content == "원본 내용"
    assert result.url == item.url


def test_LinguaDetector_예외시_en_기본값() -> None:
    """lingua 라이브러리 오류 시 'en'을 기본값으로 반환해야 한다."""
    detector = LinguaDetector()
    with patch.object(
        detector, "_do_detect", side_effect=ImportError("lingua 없음")
    ):
        result = detector.detect(_news())
    assert result.lang == "en"


def test_ChainedDetector_소스기반_판단() -> None:
    """ChainedLanguageDetector는 소스 기반으로 즉시 결정해야 한다."""
    detector = ChainedLanguageDetector()
    ko = detector.detect(_news(source_id="geeknews"))
    en = detector.detect(_news(source_id="hackernews"))
    assert ko.lang == "ko"
    assert en.lang == "en"


def test_LinguaDetector_content_None_처리() -> None:
    """content가 None일 때 제목만으로 언어를 감지해야 한다."""
    detector = LinguaDetector()
    with patch.object(detector, "_do_detect", return_value="ko") as mock:
        result = detector.detect(_news(content=None, title="한국어 제목"))
    assert result.lang == "ko"
    # _do_detect에 전달된 content가 None이어야 한다
    mock.assert_called_once_with("한국어 제목", None)
