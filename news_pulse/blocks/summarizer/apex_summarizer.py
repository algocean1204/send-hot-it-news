"""
ApexSummarizer — APEX-4B 모델 기반 요약기.

한국어 소스는 한국어로 직접 요약, 영어 소스는 영어로 요약한다.
추론은 주입받은 OllamaEngine에 위임한다.
"""
from __future__ import annotations

import logging

from news_pulse.blocks.model_engine.protocol import ModelEngine
from news_pulse.models.news import NewsItem, SummaryResult

logger = logging.getLogger(__name__)

_SUMMARIZER_NAME = "ApexSummarizer"

_PROMPT_KO = """다음 뉴스를 한국어로 2-3문장으로 간결하게 요약해주세요.

제목: {title}
내용: {content}

요약:"""

_PROMPT_EN = """Summarize the following news in 2-3 concise sentences in English.

Title: {title}
Content: {content}

Summary:"""


class ApexSummarizer:
    """APEX-4B 모델로 뉴스를 요약하는 1차 요약기."""

    def __init__(self, model_name: str = "apex-i-compact") -> None:
        """model_name: Ollama에서 사용할 APEX 모델 이름."""
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
            logger.warning("ApexSummarizer 실패: %s", exc)
            raise

    def _do_summarize(self, item: NewsItem, engine: ModelEngine) -> SummaryResult:
        """올바른 모델을 로드한 뒤 요약 프롬프트를 구성하고 응답을 파싱한다."""
        # 폴백 체인 진입 시에도 항상 올바른 모델을 로드하도록 명시적 호출
        engine.load(self._model_name, keep_alive=0)
        content = item.content or item.title
        if item.lang == "ko":
            prompt = _PROMPT_KO.format(title=item.title, content=content[:2000])
        else:
            prompt = _PROMPT_EN.format(title=item.title, content=content[:2000])
        response = engine.generate(prompt, {"temperature": 0.3, "num_predict": 256})
        return SummaryResult(
            item_url=item.url,
            summary_text=response.strip(),
            original_lang=item.lang,
            summarizer_used=_SUMMARIZER_NAME,
            translator_used=None,
            error=None,
        )
