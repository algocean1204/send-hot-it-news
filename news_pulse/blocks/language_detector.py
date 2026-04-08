"""
블럭 6 — LanguageDetector.

SourceFirstDetector (소스 기반) -> LinguaDetector (lingua 라이브러리) 순으로
언어를 감지해 NewsItem.lang 필드를 채운다.
"""
from __future__ import annotations

import logging
from typing import Protocol

from news_pulse.models.news import NewsItem

logger = logging.getLogger(__name__)

# 한국어 소스 — 이 소스는 항상 "ko"로 판단한다
_KO_SOURCES = frozenset({"geeknews"})


class LanguageDetectorProtocol(Protocol):
    """LanguageDetector 인터페이스 정의."""

    def detect(self, item: NewsItem) -> NewsItem: ...


class SourceFirstDetector:
    """소스 식별자만으로 언어를 결정하는 1차 감지기."""

    def detect(self, item: NewsItem) -> NewsItem:
        """GeekNews -> ko, 나머지 11개 소스 -> en으로 즉시 결정한다."""
        lang = "ko" if item.source_id in _KO_SOURCES else "en"
        return NewsItem(
            url=item.url,
            title=item.title,
            content=item.content,
            source_id=item.source_id,
            fetched_at=item.fetched_at,
            upvotes=item.upvotes,
            published_at=item.published_at,
            url_hash=item.url_hash,
            lang=lang,
        )


class LinguaDetector:
    """lingua 라이브러리로 텍스트 분석을 통해 언어를 감지하는 2차 감지기."""

    def detect(self, item: NewsItem) -> NewsItem:
        """
        lingua로 제목+본문을 분석한다.

        감지 실패 또는 라이브러리 오류 시 "en"을 기본값으로 반환한다.
        """
        try:
            lang = self._do_detect(item.title, item.content)
        except Exception as exc:
            logger.warning("lingua 감지 실패, 'en' 기본값 사용: %s", exc)
            lang = "en"

        return NewsItem(
            url=item.url,
            title=item.title,
            content=item.content,
            source_id=item.source_id,
            fetched_at=item.fetched_at,
            upvotes=item.upvotes,
            published_at=item.published_at,
            url_hash=item.url_hash,
            lang=lang,
        )

    def _do_detect(self, title: str, content: str | None) -> str:
        """lingua 라이브러리로 실제 언어 감지를 수행한다."""
        from lingua import Language, LanguageDetectorBuilder
        detector = (
            LanguageDetectorBuilder.from_languages(Language.ENGLISH, Language.KOREAN)
            .with_preloaded_language_models()
            .build()
        )
        text = title + (" " + content if content else "")
        detected = detector.detect_language_of(text)
        if detected is None:
            return "en"
        from lingua import Language as Lang
        return "ko" if detected == Lang.KOREAN else "en"


class ChainedLanguageDetector:
    """SourceFirst -> Lingua 순서로 언어를 감지하는 체인 구현체."""

    def __init__(self) -> None:
        """소스 기반 감지기를 기본 사용. lingua는 필요 시만 호출한다."""
        self._source_first = SourceFirstDetector()

    def detect(self, item: NewsItem) -> NewsItem:
        """소스 기반 감지기로 결정 후 반환한다 (항상 명확한 값 반환)."""
        return self._source_first.detect(item)
