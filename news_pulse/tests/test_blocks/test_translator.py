"""
Translator 단위 테스트.

한국어 소스 건너뜀, 영어 번역, 번역 실패 시 원본 유지를 검증한다.
"""
from __future__ import annotations

from unittest.mock import MagicMock

from news_pulse.blocks.translator.claude_cli_translator import ClaudeCliTranslator
from news_pulse.blocks.translator.kanana_translator import KananaTranslator
from news_pulse.models.news import SummaryResult


def _make_result(lang: str = "en", summary: str = "English summary") -> SummaryResult:
    """테스트용 SummaryResult를 생성한다."""
    return SummaryResult(
        item_url="http://example.com",
        summary_text=summary,
        original_lang=lang,
        summarizer_used="ApexSummarizer",
        translator_used=None,
        error=None,
    )


def _make_engine(response: str = "한국어 번역") -> MagicMock:
    """mock ModelEngine을 생성한다."""
    engine = MagicMock()
    engine.generate.return_value = response
    return engine


def test_kanana_skips_korean_source() -> None:
    """한국어 소스는 번역을 건너뛰고 원본을 반환해야 한다."""
    translator = KananaTranslator()
    result = _make_result(lang="ko", summary="한국어 요약")
    engine = _make_engine()

    translated = translator.translate(result, engine)
    assert translated.summary_text == "한국어 요약"
    assert translated.translator_used is None
    engine.generate.assert_not_called()


def test_kanana_translates_english() -> None:
    """영어 요약을 한국어로 번역해야 한다."""
    translator = KananaTranslator()
    result = _make_result(lang="en", summary="English summary")
    engine = _make_engine("한국어 번역된 내용")

    translated = translator.translate(result, engine)
    assert translated.summary_text == "한국어 번역된 내용"
    assert translated.translator_used == "KananaTranslator"


def test_claude_cli_translator_fallback_on_failure() -> None:
    """번역 실패 시 영어 원본을 유지하고 error 플래그를 설정해야 한다."""
    translator = ClaudeCliTranslator()
    result = _make_result(lang="en", summary="Original English")
    engine = MagicMock()
    engine.generate.side_effect = RuntimeError("CLI 오류")

    translated = translator.translate(result, engine)
    assert translated.summary_text == "Original English"
    assert translated.error is not None
    assert "번역 실패" in translated.error


def test_claude_cli_translator_skips_korean() -> None:
    """한국어 소스는 Claude CLI 번역도 건너뛰어야 한다."""
    translator = ClaudeCliTranslator()
    result = _make_result(lang="ko", summary="한국어")
    engine = _make_engine()

    translated = translator.translate(result, engine)
    assert translated.summary_text == "한국어"
    engine.generate.assert_not_called()
