"""
WhitelistFilter — 화이트리스트 키워드 매칭 블럭.

TierRouter의 _passes_tier3에서 보조 모듈로 사용한다.
DB에서 키워드를 한 번 로드해 파이프라인 1회 실행 동안 캐시한다.
"""
from __future__ import annotations

import logging

from news_pulse.models.news import NewsItem

logger = logging.getLogger(__name__)


class WhitelistFilter:
    """DB에서 로드한 키워드가 아이템 제목/본문에 포함되는지 검사한다."""

    def __init__(self, keywords: set[str]) -> None:
        """keywords: 소문자 정규화된 화이트리스트 키워드 집합."""
        # 소문자 정규화 — DB 저장 시 이미 소문자이므로 방어적으로 재처리
        self._keywords: set[str] = {k.lower() for k in keywords}

    def matches(self, item: NewsItem) -> bool:
        """제목+본문에 화이트리스트 키워드가 포함되면 True를 반환한다."""
        if not self._keywords:
            return False
        text = (item.title + " " + (item.content or "")).lower()
        return any(kw in text for kw in self._keywords)
