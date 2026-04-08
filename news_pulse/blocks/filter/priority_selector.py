"""
PrioritySelector — 최종 8건 선택기.

Tier별 우선순위 정렬 후 최종 8건을 선택한다.
Tier 1 -> Tier 2 -> Tier 3(업보트 높은 순) 순서로 정렬한다.
Tier 1+2가 8건 초과 시 허용 (allow_tier1_overflow=true 정책).
"""
from __future__ import annotations

import logging

from news_pulse.models.config import Config
from news_pulse.models.news import NewsItem

logger = logging.getLogger(__name__)

# 최대 선택 건수 (Tier 1+2 초과 허용)
_MAX_ITEMS = 8

# Tier 분류용 소스 매핑
_TIER1_SOURCES = frozenset({
    "anthropic", "openai", "deepmind", "huggingface",
    "claude_code_releases", "cline_releases", "cursor_changelog",
})
_TIER2_SOURCES = frozenset({"geeknews"})


class PrioritySelector:
    """Tier별 우선순위로 최대 8건을 선택하는 필터."""

    def apply(self, items: list[NewsItem], config: Config) -> list[NewsItem]:
        """
        Tier 1 -> Tier 2 -> Tier 3 순으로 정렬 후 최대 8건 반환한다.

        예외 발생 시 원본 앞 8건을 반환한다.
        """
        try:
            return self._do_select(items, config)
        except Exception as exc:
            logger.warning("PrioritySelector 실패, 건너뜀: %s", exc)
            return items[:_MAX_ITEMS]

    def _do_select(self, items: list[NewsItem], config: Config) -> list[NewsItem]:
        """Tier별로 분리 후 우선순위 정렬해 선택한다."""
        tier1 = [i for i in items if i.source_id in _TIER1_SOURCES]
        tier2 = [i for i in items if i.source_id in _TIER2_SOURCES]
        tier3 = sorted(
            [i for i in items if i.source_id not in _TIER1_SOURCES | _TIER2_SOURCES],
            key=lambda x: x.upvotes or 0,
            reverse=True,
        )

        # Tier 1+2가 8건 초과 시 모두 허용
        priority = tier1 + tier2
        if len(priority) >= _MAX_ITEMS:
            return priority

        # 남은 자리를 Tier 3로 채움
        remaining = _MAX_ITEMS - len(priority)
        return priority + tier3[:remaining]
