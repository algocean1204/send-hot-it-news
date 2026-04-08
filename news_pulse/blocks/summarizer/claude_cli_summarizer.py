"""
ClaudeCliSummarizer — Claude CLI 기반 최종 폴백 요약기.

APEX + Kanana 모두 실패 시 사용. ClaudeCliEngine에 추론을 위임한다.
"""
from __future__ import annotations

import logging

from news_pulse.blocks.model_engine.protocol import ModelEngine
from news_pulse.models.news import NewsItem, SummaryResult

logger = logging.getLogger(__name__)

_SUMMARIZER_NAME = "ClaudeCliSummarizer"

_PROMPT_TEMPLATE = """다음 뉴스 기사를 한국어로 2-3문장으로 핵심만 요약해주세요.

제목: {title}
내용: {content}

요약:"""


class ClaudeCliSummarizer:
    """Claude CLI를 통해 뉴스를 요약하는 최종 폴백 요약기."""

    @property
    def model_display_name(self) -> str:
        """모델 추적 기록에 저장할 표시 모델명을 반환한다."""
        return "claude-cli"

    def summarize(self, item: NewsItem, engine: ModelEngine) -> SummaryResult:
        """ClaudeCliEngine으로 요약을 생성한다."""
        try:
            return self._do_summarize(item, engine)
        except Exception as exc:
            logger.error("ClaudeCliSummarizer 실패: %s", exc)
            return SummaryResult(
                item_url=item.url,
                summary_text="",
                original_lang=item.lang,
                summarizer_used=_SUMMARIZER_NAME,
                translator_used=None,
                error=str(exc),
            )

    def _do_summarize(self, item: NewsItem, engine: ModelEngine) -> SummaryResult:
        """Claude CLI 프롬프트를 구성하고 응답을 반환한다."""
        content = item.content or item.title
        prompt = _PROMPT_TEMPLATE.format(title=item.title, content=content[:3000])
        response = engine.generate(prompt, {})
        return SummaryResult(
            item_url=item.url,
            summary_text=response.strip(),
            original_lang=item.lang,
            summarizer_used=_SUMMARIZER_NAME,
            translator_used=None,
            error=None,
        )
