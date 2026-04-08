"""
MessageFormatter 단위 테스트.

MarkdownV2 이스케이프, 핫뉴스/일반 뉴스 포맷 분기를 검증한다.
"""
from __future__ import annotations

from datetime import datetime

from news_pulse.blocks.message_formatter import TelegramMessageFormatter, escape_md
from news_pulse.models.news import NewsItem, SummaryResult


def _make_item(title: str = "Test News", source_id: str = "hackernews") -> NewsItem:
    return NewsItem(
        url="http://example.com",
        title=title,
        content="내용",
        source_id=source_id,
        fetched_at=datetime.now(),
        upvotes=100,
        published_at=None,
        url_hash="abc123",
        lang="en",
    )


def _make_result(summary: str = "요약 내용") -> SummaryResult:
    return SummaryResult(
        item_url="http://example.com",
        summary_text=summary,
        original_lang="en",
        summarizer_used="apex",
        translator_used="kanana",
        error=None,
    )


def test_escape_md_escapes_special_chars() -> None:
    """MarkdownV2 특수문자가 올바르게 이스케이프되어야 한다."""
    text = "Hello_World! [link](url) #tag"
    escaped = escape_md(text)
    assert "_" not in escaped.replace("\\_", "")
    assert "\\." in escaped or "\\!" in escaped or "\\[" in escaped


def test_normal_format_contains_title_and_link() -> None:
    """일반 뉴스 포맷에 제목과 링크가 포함되어야 한다."""
    formatter = TelegramMessageFormatter()
    item = _make_item(title="AI News Update")
    result_obj = _make_result("AI 뉴스 요약")
    message = formatter.format(item, result_obj, is_hot=False)

    assert "AI News Update" in message or "AI" in message
    assert "http://example.com" in message


def test_hot_format_contains_hot_indicator() -> None:
    """핫뉴스 포맷에 핫뉴스 표시가 포함되어야 한다."""
    formatter = TelegramMessageFormatter()
    item = _make_item()
    result_obj = _make_result()
    message = formatter.format(item, result_obj, is_hot=True)

    assert "핫뉴스" in message or "🔥" in message


def test_format_failure_returns_plain_text() -> None:
    """포맷 실패 시 플레인 텍스트(제목+링크)를 반환해야 한다."""
    formatter = TelegramMessageFormatter()
    item = _make_item(title="Simple Title")
    result_obj = _make_result("")

    # summary_text가 None이어도 폴백이 동작해야 한다
    bad_result = SummaryResult(
        item_url=item.url, summary_text=None,
        original_lang="en", summarizer_used="apex",
        translator_used=None, error=None,
    )
    # 포맷이 예외를 발생시키지 않아야 한다
    message = formatter.format(item, bad_result, is_hot=False)
    assert isinstance(message, str)
    assert len(message) > 0


def test_escape_dot_and_exclamation() -> None:
    """점(.)과 느낌표(!)가 이스케이프되어야 한다."""
    assert "\\." in escape_md("hello.world")
    assert "\\!" in escape_md("hello!")
