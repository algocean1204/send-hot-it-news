"""
ThresholdCalibrator — 소스별 업보트 임계값 최적화 블럭.

최근 N일 데이터에서 소스별 통과율을 분석해 목표 통과율에 근접한
업보트 임계값을 이분 탐색으로 계산한다. Flutter F09 설정 화면에서 사용한다.
"""
from __future__ import annotations

import logging

from news_pulse.db.store import SqliteStore

logger = logging.getLogger(__name__)

# 이분 탐색 범위 — 업보트 값 최솟값/최댓값
_MIN_UPVOTES = 0
_MAX_UPVOTES = 1000


def _binary_search_threshold(
    distribution: list[dict[str, object]], target_rate: float
) -> int:
    """업보트 분포에서 목표 통과율에 맞는 임계값을 이분 탐색으로 찾는다."""
    if not distribution:
        return _MIN_UPVOTES
    total = sum(int(str(r["item_count"])) for r in distribution)
    if total == 0:
        return _MIN_UPVOTES
    lo, hi = _MIN_UPVOTES, _MAX_UPVOTES
    best = lo
    while lo <= hi:
        mid = (lo + hi) // 2
        passed = sum(
            int(str(r["item_count"]))
            for r in distribution
            if r["upvotes"] is not None and int(str(r["upvotes"])) >= mid
        )
        rate = passed / total
        if rate <= target_rate:
            best = mid
            hi = mid - 1
        else:
            lo = mid + 1
    return best


def suggest_thresholds(
    store: SqliteStore, target_rate: float = 0.4, days: int = 30
) -> list[dict[str, object]]:
    """
    소스별 최적 업보트 임계값 제안 목록을 반환한다.

    반환값: [{"source_id": str, "current": int, "suggested": int, "current_rate": float}, ...].
    """
    try:
        pass_rates = store.get_pass_rate_by_source(days=days)
        suggestions: list[dict[str, object]] = []
        for row in pass_rates:
            source_id = str(row.get("source", ""))
            total = int(str(row.get("total", 0)))
            passed = int(str(row.get("passed", 0)))
            current_rate = passed / total if total > 0 else 0.0
            distribution = store.get_upvote_distribution(source_id=source_id, days=days)
            suggested = _binary_search_threshold(distribution, target_rate)
            suggestions.append({
                "source_id": source_id,
                "current": 0,
                "suggested": suggested,
                "current_rate": round(current_rate, 4),
            })
        return suggestions
    except Exception as exc:
        logger.warning("임계값 교정 분석 실패: %s", exc)
        return []
