"""
ModelUsageTracker — 모델 추론 지연시간/성공 여부 기록 블럭.

summarize_pipeline.py에서 각 요약/번역 호출 전후에 타이밍을 측정하고
model_usage_log 테이블에 기록한다.
"""
from __future__ import annotations

import logging

from news_pulse.db.store import SqliteStore

logger = logging.getLogger(__name__)


def track(
    store: SqliteStore,
    run_id: int | None,
    item_id: int | None,
    model_name: str,
    task_type: str,
    latency_ms: int,
    success: bool,
) -> None:
    """모델 사용 기록을 model_usage_log 테이블에 저장한다. 실패 시 경고만 남긴다."""
    try:
        store.log_model_usage(
            run_id=run_id,
            processed_item_id=item_id,
            model_name=model_name,
            task_type=task_type,
            latency_ms=latency_ms,
            input_tokens=None,
            success=1 if success else 0,
        )
    except Exception as exc:
        # 추적 실패는 파이프라인을 중단하면 안 된다
        logger.warning("모델 사용 기록 저장 실패: %s", exc)
