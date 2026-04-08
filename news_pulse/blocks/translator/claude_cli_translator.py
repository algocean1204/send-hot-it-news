"""
ClaudeCliTranslator — Claude CLI 기반 폴백 번역기.

Kanana 번역 실패 시 사용. 번역 실패 시 영어 원본을 유지한다.
"""
from __future__ import annotations

import logging

from news_pulse.blocks.model_engine.protocol import ModelEngine
from news_pulse.models.news import SummaryResult

logger = logging.getLogger(__name__)

_TRANSLATOR_NAME = "ClaudeCliTranslator"

_PROMPT_TEMPLATE = """다음 영어 텍스트를 자연스러운 한국어로 번역해주세요.

영어: {text}

한국어:"""


class ClaudeCliTranslator:
    """Claude CLI로 영어를 한국어로 번역하는 폴백 번역기."""

    @property
    def model_display_name(self) -> str:
        """모델 추적 기록에 저장할 표시 모델명을 반환한다."""
        return "claude-cli"

    def translate(self, result: SummaryResult, engine: ModelEngine) -> SummaryResult:
        """
        영어 소스만 번역한다.

        번역 실패 시 영어 원본을 유지하고 error 플래그를 설정한다.
        """
        if result.original_lang == "ko":
            return result
        try:
            return self._do_translate(result, engine)
        except Exception as exc:
            logger.error("ClaudeCliTranslator 실패, 영어 원본 유지: %s", exc)
            return SummaryResult(
                item_url=result.item_url,
                summary_text=result.summary_text,
                original_lang=result.original_lang,
                summarizer_used=result.summarizer_used,
                translator_used=_TRANSLATOR_NAME,
                error=f"번역 실패: {exc}",
            )

    def _do_translate(self, result: SummaryResult, engine: ModelEngine) -> SummaryResult:
        """Claude CLI 번역 프롬프트를 구성하고 응답을 반환한다."""
        # summary_text가 없으면 번역할 내용이 없으므로 원본 결과를 그대로 반환
        if not result.summary_text:
            return result
        prompt = _PROMPT_TEMPLATE.format(text=result.summary_text)
        translated = engine.generate(prompt, {})
        return SummaryResult(
            item_url=result.item_url,
            summary_text=translated.strip(),
            original_lang=result.original_lang,
            summarizer_used=result.summarizer_used,
            translator_used=_TRANSLATOR_NAME,
            error=None,
        )
