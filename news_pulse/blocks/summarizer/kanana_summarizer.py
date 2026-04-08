"""
KananaSummarizer — kanana-1.5-8b 모델 기반 요약기.

APEX 폴백 시 사용. 한국어 특화 모델로 요약한다.
"""
from __future__ import annotations

import logging

from news_pulse.blocks.model_engine.protocol import ModelEngine
from news_pulse.models.news import NewsItem, SummaryResult

logger = logging.getLogger(__name__)

_SUMMARIZER_NAME = "KananaSummarizer"

_PROMPT_TEMPLATE = """다음 뉴스 기사를 한국어로 2-3문장으로 요약해주세요.

제목: {title}
내용: {content}

요약:"""


class KananaSummarizer:
    """kanana-1.5-8b 모델로 뉴스를 요약하는 2차 요약기 (APEX 폴백)."""

    def __init__(self, model_name: str = "kanana-1.5-8b") -> None:
        """model_name: Ollama에서 사용할 Kanana 모델 이름."""
        self._model_name = model_name

    @property
    def model_display_name(self) -> str:
        """모델 추적 기록에 저장할 실제 모델명을 반환한다."""
        return self._model_name

    def summarize(self, item: NewsItem, engine: ModelEngine) -> SummaryResult:
        """프롬프트를 구성하고 ModelEngine에 추론을 요청한다."""
        try:
            return self._do_summarize(item, engine)
        except Exception as exc:
            logger.warning("KananaSummarizer 실패: %s", exc)
            raise

    def _do_summarize(self, item: NewsItem, engine: ModelEngine) -> SummaryResult:
        """올바른 모델을 로드한 뒤 Kanana 모델용 프롬프트로 요약을 생성한다."""
        # APEX 폴백 진입 시에도 Kanana 모델을 정확히 로드
        engine.load(self._model_name, keep_alive=0)
        content = item.content or item.title
        prompt = _PROMPT_TEMPLATE.format(title=item.title, content=content[:2000])
        response = engine.generate(prompt, {"temperature": 0.3, "num_predict": 256})
        return SummaryResult(
            item_url=item.url,
            summary_text=response.strip(),
            original_lang=item.lang,
            summarizer_used=_SUMMARIZER_NAME,
            translator_used=None,
            error=None,
        )
