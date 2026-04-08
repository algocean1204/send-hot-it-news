"""
블럭 12 — MessageFormatter.

텔레그램 MarkdownV2 포맷으로 뉴스 메시지를 생성한다.
핫뉴스는 상세 요약, 일반 뉴스는 한줄 요약 형식으로 출력한다.
"""
from __future__ import annotations

import logging
import re
from typing import Protocol

logger = logging.getLogger(__name__)

from news_pulse.models.news import NewsItem, SummaryResult

# MarkdownV2 이스케이프 대상 문자 목록 — 백슬래시 자체도 이스케이프 필요
_ESCAPE_CHARS = r"\_*[]()~`>#+-=|{}.!"


class MessageFormatterProtocol(Protocol):
    """MessageFormatter 인터페이스 정의."""

    def format(self, item: NewsItem, result: SummaryResult, is_hot: bool) -> str: ...


def escape_md(text: str) -> str:
    """MarkdownV2 특수문자를 이스케이프한다. 백슬래시를 가장 먼저 처리해 이중 이스케이프를 방지한다."""
    return re.sub(r"([\\\_*\[\]()~`>#+=|{}.!\-])", r"\\\1", text)


class TelegramMessageFormatter:
    """텔레그램 MarkdownV2 형식으로 뉴스를 포맷하는 구현체."""

    def format(self, item: NewsItem, result: SummaryResult, is_hot: bool) -> str:
        """
        핫뉴스/일반 뉴스에 따라 다른 포맷으로 메시지를 생성한다.

        포맷 실패 시 이스케이프 없이 제목+링크만 반환한다.
        """
        try:
            return self._format_hot(item, result) if is_hot else self._format_normal(item, result)
        except Exception as exc:
            logger.warning("메시지 포맷 실패, 제목+링크로 폴백: %s", exc)
            return f"{item.title}\n{item.url}"

    def _format_normal(self, item: NewsItem, result: SummaryResult) -> str:
        """일반 뉴스: 제목 + 한줄 요약 + 링크."""
        title = escape_md(item.title)
        summary = escape_md(result.summary_text[:200] if result.summary_text else "")
        source = escape_md(item.source_id)
        url = item.url

        lines = [
            f"📰 *{title}*",
            f"_{summary}_",
            f"\\[{source}\\] [링크]({url})",
        ]
        return "\n".join(lines)

    def _format_hot(self, item: NewsItem, result: SummaryResult) -> str:
        """핫뉴스: 제목 + 상세 요약 + 주요 내용 + 링크."""
        title = escape_md(item.title)
        summary = escape_md(result.summary_text if result.summary_text else "")
        source = escape_md(item.source_id)
        url = item.url
        upvotes_text = f" \\({item.upvotes}↑\\)" if item.upvotes else ""

        lines = [
            f"🔥 *\\[핫뉴스\\] {title}*{upvotes_text}",
            f"\\-\\-\\-",
            f"{summary}",
            f"",
            f"\\[{source}\\] [원문 보기]({url})",
        ]
        return "\n".join(lines)
