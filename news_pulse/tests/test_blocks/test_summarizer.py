"""
Summarizer + FallbackChain 단위 테스트.

FallbackChain 동작 (첫 번째 실패 -> 두 번째 성공)을 검증한다.
"""
from __future__ import annotations

from datetime import datetime
from unittest.mock import MagicMock

import pytest

from news_pulse.blocks.summarizer.apex_summarizer import ApexSummarizer
from news_pulse.blocks.summarizer.claude_cli_summarizer import ClaudeCliSummarizer
from news_pulse.core.fallback_chain import FallbackChain
from news_pulse.models.news import NewsItem


def _make_item(lang: str = "en") -> NewsItem:
    """테스트용 NewsItem을 생성한다."""
    return NewsItem(
        url="http://example.com",
        title="Test AI News",
        content="AI is advancing rapidly.",
        source_id="hackernews",
        fetched_at=datetime.now(),
        upvotes=100,
        published_at=None,
        url_hash="abc123",
        lang=lang,
    )


def _make_engine(response: str = "요약 결과") -> MagicMock:
    """mock ModelEngine을 생성한다."""
    engine = MagicMock()
    engine.generate.return_value = response
    return engine


def test_apex_summarizer_returns_result() -> None:
    """ApexSummarizer가 정상적으로 SummaryResult를 반환해야 한다."""
    summarizer = ApexSummarizer()
    engine = _make_engine("AI가 빠르게 발전하고 있다.")
    result = summarizer.summarize(_make_item(), engine)

    assert result.summary_text == "AI가 빠르게 발전하고 있다."
    assert result.summarizer_used == "ApexSummarizer"
    assert result.error is None


def test_apex_summarizer_ko_source() -> None:
    """한국어 소스는 한국어 프롬프트를 사용해야 한다."""
    summarizer = ApexSummarizer()
    engine = _make_engine("한국어 요약")
    result = summarizer.summarize(_make_item(lang="ko"), engine)

    assert result.original_lang == "ko"
    assert result.translator_used is None


def test_fallback_chain_uses_second_on_first_failure() -> None:
    """첫 번째 구현체 실패 시 두 번째 구현체로 폴백해야 한다."""
    failing = MagicMock()
    failing.summarize.side_effect = RuntimeError("첫 번째 구현체 실패")

    succeeding = MagicMock()
    succeeding.summarize.return_value = "두 번째 성공"

    chain = FallbackChain([failing, succeeding])
    result = chain.execute("summarize", _make_item(), _make_engine())

    assert result == "두 번째 성공"
    failing.summarize.assert_called_once()
    succeeding.summarize.assert_called_once()


def test_fallback_chain_raises_when_all_fail() -> None:
    """모든 구현체가 실패하면 마지막 예외를 올려야 한다."""
    fail1 = MagicMock()
    fail1.summarize.side_effect = RuntimeError("첫 번째 실패")
    fail2 = MagicMock()
    fail2.summarize.side_effect = RuntimeError("두 번째 실패")

    chain = FallbackChain([fail1, fail2])
    with pytest.raises(RuntimeError, match="두 번째 실패"):
        chain.execute("summarize", _make_item(), _make_engine())


def test_claude_cli_summarizer_returns_error_on_failure() -> None:
    """ClaudeCliSummarizer는 실패 시 error 필드를 설정한 SummaryResult를 반환해야 한다."""
    summarizer = ClaudeCliSummarizer()
    engine = MagicMock()
    engine.generate.side_effect = RuntimeError("Claude CLI 오류")

    result = summarizer.summarize(_make_item(), engine)
    assert result.error is not None
    assert "Claude CLI" in result.error
