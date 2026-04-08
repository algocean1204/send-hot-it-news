"""전송 파이프라인 원자 모듈. HotDetector -> Formatter -> Sender 순서로 전송한다."""
from __future__ import annotations
import logging
from typing import Protocol
from news_pulse.models.config import Config
from news_pulse.models.news import NewsItem, SummaryResult
from news_pulse.models.telegram import SendResult
logger = logging.getLogger(__name__)


class _HotDetector(Protocol):
    def detect(self, item: NewsItem, result: SummaryResult, config: Config) -> bool: ...


class _Formatter(Protocol):
    def format(self, item: NewsItem, result: SummaryResult, is_hot: bool) -> str: ...


class _Sender(Protocol):
    def send(self, message: str, config: Config) -> SendResult: ...


def send_messages(
    items: list[NewsItem], results: list[SummaryResult],
    hot_detector: _HotDetector, formatter: _Formatter, sender: _Sender, config: Config,
) -> int:
    """각 아이템을 핫뉴스 감지 -> 포맷 -> 전송 순서로 처리하고 성공 건수를 반환한다."""
    total_sent = 0
    for item, result in zip(items, results):
        try:
            is_hot = hot_detector.detect(item, result, config)
            message = formatter.format(item, result, is_hot)
            send_result = sender.send(message, config)
            total_sent += send_result.success_count
        except Exception as exc:
            logger.warning("메시지 전송 실패 (%s): %s", item.url, exc)
    return total_sent
