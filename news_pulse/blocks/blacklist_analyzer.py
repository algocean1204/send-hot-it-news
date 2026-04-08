"""
BlacklistAnalyzer — 필터링된 아이템 키워드 빈도 분석 블럭.

최근 N일간 필터링된 아이템의 제목에서 단어 빈도를 집계하고
블랙리스트 추가 후보를 반환한다. Flutter F08 설정 화면에서 사용한다.
"""
from __future__ import annotations

import logging

from news_pulse.db.store import SqliteStore

logger = logging.getLogger(__name__)


def suggest_blacklist_keywords(
    store: SqliteStore, days: int = 30, limit: int = 10
) -> list[dict[str, object]]:
    """
    필터링된 아이템의 제목 단어 빈도를 분석해 블랙리스트 후보를 반환한다.

    반환값: [{"keyword": str, "frequency": int}, ...] (빈도 내림차순 상위 limit건).
    """
    try:
        rows = store.get_filtered_word_frequency(days=days, limit=limit)
        return [
            {"keyword": str(r["title"]), "frequency": int(str(r["freq"]))}
            for r in rows
        ]
    except Exception as exc:
        logger.warning("블랙리스트 후보 분석 실패: %s", exc)
        return []
