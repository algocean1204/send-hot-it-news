"""
TierRouter — 소스별 Tier 분류 필터.

소스 ID를 기반으로 각 아이템에 Tier를 적용하고 할당량을 고려한 리스트를 반환한다.
Tier 정책: 1(AI랩+GitHub) / 2(GeekNews) / 3(Reddit, HN).
WhitelistFilter를 주입받아 업보트 미달 Tier3 아이템도 키워드 매칭 시 통과시킨다.
"""
from __future__ import annotations

import logging

from news_pulse.blocks.filter.whitelist_filter import WhitelistFilter
from news_pulse.models.config import Config
from news_pulse.models.news import NewsItem

logger = logging.getLogger(__name__)

# 소스 ID -> Tier 매핑 (config.sources를 우선, 없으면 이 기본값 사용)
_DEFAULT_TIER_MAP: dict[str, int] = {
    "anthropic": 1,
    "openai": 1,
    "deepmind": 1,
    "huggingface": 1,
    "claude_code_releases": 1,
    "cline_releases": 1,
    "cursor_changelog": 1,
    "geeknews": 2,
    "hackernews": 3,
    "reddit_localllama": 3,
    "reddit_claudeai": 3,
    "reddit_cursor": 3,
}


class TierRouter:
    """소스 ID에 따라 아이템을 Tier별로 분류하는 필터."""

    def __init__(self, whitelist_filter: WhitelistFilter | None = None) -> None:
        """whitelist_filter: 화이트리스트 키워드 매칭기 (None이면 비활성)."""
        self._whitelist = whitelist_filter

    def apply(self, items: list[NewsItem], config: Config) -> list[NewsItem]:
        """
        소스별 Tier를 결정하고, 업보트 임계값을 통과한 Tier3 아이템을 필터링한다.

        예외 발생 시 이 필터를 건너뛰고 원본을 반환한다.
        """
        try:
            return self._do_route(items, config)
        except Exception as exc:
            logger.warning("TierRouter 실패, 건너뜀: %s", exc)
            return items

    def _do_route(self, items: list[NewsItem], config: Config) -> list[NewsItem]:
        """Tier별 필터링 및 임계값 적용."""
        tier_map = self._build_tier_map(config)
        result: list[NewsItem] = []
        for item in items:
            tier = tier_map.get(item.source_id, 3)
            if tier in (1, 2):
                result.append(item)
            elif tier == 3 and self._passes_tier3(item, config):
                result.append(item)
        return result

    def _build_tier_map(self, config: Config) -> dict[str, int]:
        """config.sources에서 Tier 매핑을 빌드한다."""
        tier_map = dict(_DEFAULT_TIER_MAP)
        for source in config.sources:
            tier_map[source.source_id] = source.tier
        return tier_map

    def _passes_tier3(self, item: NewsItem, config: Config) -> bool:
        """HN/Reddit 업보트 임계값을 통과하거나 화이트리스트에 매칭되면 True를 반환한다."""
        # 화이트리스트 키워드 매칭 시 업보트 임계값 무관하게 통과
        if self._whitelist is not None and self._whitelist.matches(item):
            return True
        if item.upvotes is None:
            return False
        if "reddit" in item.source_id:
            return item.upvotes >= config.tier3_reddit_threshold
        if item.source_id == "hackernews":
            return item.upvotes >= config.tier3_hn_threshold
        return True
