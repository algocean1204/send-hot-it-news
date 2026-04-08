"""
BlacklistFilter — 키워드 블랙리스트 필터.

제목 또는 본문에 블랙리스트 키워드가 포함된 아이템을 제거한다.
대소문자 무시 매칭. 예외 발생 시 이 필터를 건너뛰고 원본을 반환한다.
"""
from __future__ import annotations

import logging

from news_pulse.models.config import Config
from news_pulse.models.news import NewsItem

logger = logging.getLogger(__name__)


class BlacklistFilter:
    """키워드 블랙리스트에 매칭되는 아이템을 제거하는 필터."""

    def apply(self, items: list[NewsItem], config: Config) -> list[NewsItem]:
        """블랙리스트 키워드를 포함한 아이템을 걸러낸다."""
        if not config.blacklist_keywords:
            return items
        try:
            return self._do_filter(items, config.blacklist_keywords)
        except Exception as exc:
            logger.warning("BlacklistFilter 실패, 건너뜀: %s", exc)
            return items

    def _do_filter(
        self, items: list[NewsItem], keywords: list[str]
    ) -> list[NewsItem]:
        """각 아이템의 제목+본문에 키워드가 없는 것만 남긴다."""
        lower_keywords = [k.lower() for k in keywords]
        filtered: list[NewsItem] = []
        for item in items:
            text = (item.title + " " + (item.content or "")).lower()
            if not any(kw in text for kw in lower_keywords):
                filtered.append(item)
        return filtered
