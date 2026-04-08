"""필터 파이프라인 원자 모듈. 필터를 순서대로 적용해 통과한 아이템을 반환한다."""
from __future__ import annotations
import logging
from typing import Protocol
from news_pulse.models.config import Config
from news_pulse.models.news import NewsItem
logger = logging.getLogger(__name__)


class FilterProtocol(Protocol):
    """필터 인터페이스 — apply 메서드를 가진 객체임을 보증한다."""
    def apply(self, items: list[NewsItem], config: Config) -> list[NewsItem]: ...


def apply_filters(
    filters: list[FilterProtocol], items: list[NewsItem], config: Config
) -> list[NewsItem]:
    """
    필터 목록을 순서대로 적용해 통과한 아이템을 반환한다.

    각 필터 예외 시 경고 후 해당 필터를 건너뛴다.
    """
    for f in filters:
        try:
            items = f.apply(items, config)
        except Exception as exc:
            logger.warning("필터 실패, 건너뜀: %s", exc)
    return items
