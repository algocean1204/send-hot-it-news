"""
요약/번역 파이프라인 원자 모듈.

메모리 상태에 따라 엔진을 선택해 요약 후 번역한다.
F04: 모델 추적 — 사용된 모델명을 DB에 저장한다.
F06: 지연시간 측정 — 요약/번역 소요시간을 model_usage_log에 기록한다.
"""
from __future__ import annotations

import logging
import time

from news_pulse.blocks.model_usage_tracker import track
from news_pulse.core.fallback_chain import FallbackChain
from news_pulse.db.store import SqliteStore
from news_pulse.blocks.model_engine.ollama_engine import OllamaEngine
from news_pulse.models.config import Config
from news_pulse.models.news import NewsItem, SummaryResult
from news_pulse.models.pipeline import MemoryStatus

logger = logging.getLogger(__name__)


def _get_display_name(chain: FallbackChain[SummaryResult], used_name: str) -> str:
    """체인 구현체 중 summarizer_used/translator_used와 일치하는 model_display_name을 반환한다."""
    for impl in chain._impls:
        if type(impl).__name__ == used_name:
            display = getattr(impl, "model_display_name", None)
            if isinstance(display, str):
                return display
    return used_name


def _run_summarize(
    items: list[NewsItem],
    engine: object,
    chain: FallbackChain[SummaryResult],
    store: SqliteStore | None,
    run_id: int | None,
) -> list[SummaryResult]:
    """각 아이템을 요약해 SummaryResult 목록을 반환한다. 실패 시 error 필드에 기록한다."""
    results: list[SummaryResult] = []
    for item in items:
        start_ts = time.monotonic()
        success = True
        result: SummaryResult
        try:
            result = chain.execute("summarize", item, engine)
        except Exception as exc:
            success = False
            logger.warning("요약 실패 (%s): %s", item.url, exc)
            result = SummaryResult(
                item_url=item.url, summary_text="", original_lang=item.lang,
                summarizer_used="none", translator_used=None, error=str(exc),
            )
        latency_ms = int((time.monotonic() - start_ts) * 1000)
        if store is not None:
            display_name = _get_display_name(chain, result.summarizer_used)
            track(store, run_id, item.db_id, display_name, "summarize", latency_ms, success)
        results.append(result)
    return results


def summarize_and_translate(
    items: list[NewsItem],
    memory_status: MemoryStatus,
    ollama: OllamaEngine,
    claude_cli: object,
    summarizer_chain: FallbackChain[SummaryResult],
    translator_chain: FallbackChain[SummaryResult],
    config: Config,
    store: SqliteStore | None = None,
    run_id: int | None = None,
) -> tuple[list[SummaryResult], int]:
    """요약 및 번역을 수행하고 (결과 목록, 성공 건수)를 반환한다."""
    is_local = memory_status == "local_llm"
    engine = ollama if is_local else claude_cli
    if is_local:
        ollama.load(config.apex_model_name, keep_alive=0)
    results = _run_summarize(items, engine, summarizer_chain, store, run_id)
    if is_local:
        ollama.unload(config.apex_model_name)
        ollama.load(config.kanana_model_name, keep_alive=0)
    translated: list[SummaryResult] = []
    for item, result in zip(items, results):
        start_ts = time.monotonic()
        success = True
        translated_result: SummaryResult
        try:
            translated_result = translator_chain.execute("translate", result, engine)
        except Exception as exc:
            success = False
            logger.warning("번역 실패 (%s): %s", result.item_url, exc)
            translated_result = result
        latency_ms = int((time.monotonic() - start_ts) * 1000)
        if store is not None and translated_result.translator_used is not None:
            display_name = _get_display_name(translator_chain, translated_result.translator_used)
            track(store, run_id, item.db_id, display_name, "translate", latency_ms, success)
        # F04: 모델명을 DB에 저장 (db_id가 있는 경우만)
        if store is not None and item.db_id is not None:
            summarizer_display = _get_display_name(
                summarizer_chain, translated_result.summarizer_used
            )
            translator_display = (
                _get_display_name(translator_chain, translated_result.translator_used)
                if translated_result.translator_used else None
            )
            updates: dict[str, object] = {"summarizer_model": summarizer_display}
            if translator_display is not None:
                updates["translator_model"] = translator_display
            try:
                store.update_processed_item(item.db_id, updates)
            except Exception as exc:
                logger.warning("모델 추적 DB 저장 실패: %s", exc)
        translated.append(translated_result)
    if is_local:
        ollama.unload(config.kanana_model_name)
    return translated, sum(1 for r in translated if not r.error)
