"""
DigestFormatter — 다이제스트 메시지 포맷터 블럭.

하루치 뉴스 아이템을 핫뉴스 우선, 일반뉴스 후 순서로 묶어
Telegram 4096자 제한에 맞게 분할한 메시지 목록을 반환한다.
"""
from __future__ import annotations

import logging

from news_pulse.models.news import NewsItem, SummaryResult

logger = logging.getLogger(__name__)

# Telegram 메시지 최대 길이 — 초과 시 다음 메시지로 분할
_MAX_MSG_LEN = 4096
# 다이제스트 헤더
_HEADER = "📋 오늘의 AI 뉴스 다이제스트\n\n"


def _format_item(item: NewsItem, result: SummaryResult, is_hot: bool) -> str:
    """단일 아이템을 한줄 형식으로 포맷한다."""
    prefix = "🔥" if is_hot else "📰"
    summary = (result.summary_text or "")[:120]
    return f"{prefix} {item.title}\n{summary}\n{item.url}\n"


def format_digest(items: list[tuple[NewsItem, SummaryResult, bool]]) -> list[str]:
    """
    아이템 목록을 다이제스트 메시지로 포맷하고 4096자 단위로 분할한다.

    items: (NewsItem, SummaryResult, is_hot) 튜플 목록.
    반환값: 전송할 메시지 문자열 목록.
    """
    # 핫뉴스 먼저, 일반뉴스 후 정렬
    sorted_items = sorted(items, key=lambda t: (not t[2], t[0].url))
    messages: list[str] = []
    current = _HEADER
    for item, result, is_hot in sorted_items:
        entry = _format_item(item, result, is_hot)
        if len(current) + len(entry) > _MAX_MSG_LEN:
            messages.append(current.rstrip())
            current = entry
        else:
            current += entry
    if current.strip():
        messages.append(current.rstrip())
    return messages
