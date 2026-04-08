"""
KananaTranslator — kanana-1.5-8b 모델 기반 번역기.

영어 요약을 한국어로 번역한다. 한국어 소스는 번역을 건너뛴다.
"""
from __future__ import annotations

import logging

from news_pulse.blocks.model_engine.protocol import ModelEngine
from news_pulse.models.news import SummaryResult

logger = logging.getLogger(__name__)

_TRANSLATOR_NAME = "KananaTranslator"

_PROMPT_TEMPLATE = """다음 영어 텍스트를 자연스러운 한국어로 번역해주세요.

영어: {text}

한국어:"""


class KananaTranslator:
    """kanana-1.5-8b 모델로 영어를 한국어로 번역하는 1차 번역기."""

    def __init__(self, model_name: str = "kanana-1.5-8b") -> None:
        """model_name: Ollama에서 사용할 Kanana 모델 이름."""
        self._model_name = model_name

    @property
    def model_display_name(self) -> str:
        """모델 추적 기록에 저장할 실제 모델명을 반환한다."""
        return self._model_name

    def translate(self, result: SummaryResult, engine: ModelEngine) -> SummaryResult:
        """
        영어 소스만 번역한다.

        한국어 소스(original_lang == "ko")는 원본을 그대로 반환한다.
        """
        if result.original_lang == "ko":
            return result
        try:
            return self._do_translate(result, engine)
        except Exception as exc:
            logger.warning("KananaTranslator 실패: %s", exc)
            raise

    def _do_translate(self, result: SummaryResult, engine: ModelEngine) -> SummaryResult:
        """올바른 모델을 로드한 뒤 번역 프롬프트를 구성하고 응답을 반환한다."""
        # summary_text가 없으면 번역할 내용이 없으므로 원본 결과를 그대로 반환
        if not result.summary_text:
            return result
        # 폴백 체인 진입 시에도 Kanana 모델을 정확히 로드
        engine.load(self._model_name, keep_alive=0)
        prompt = _PROMPT_TEMPLATE.format(text=result.summary_text)
        translated = engine.generate(prompt, {"temperature": 0.2, "num_predict": 512})
        return SummaryResult(
            item_url=result.item_url,
            summary_text=translated.strip(),
            original_lang=result.original_lang,
            summarizer_used=result.summarizer_used,
            translator_used=_TRANSLATOR_NAME,
            error=None,
        )
