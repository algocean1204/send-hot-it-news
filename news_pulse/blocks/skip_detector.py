"""
SkipDetector — launchd 스케줄 누락 감지 블럭.

현재 시각과 마지막 실행 시각을 비교해 놓친 시간대를 계산하고,
schedule_log 테이블에 'missed' 상태로 기록한다.
launchd 스케줄: 09:00~00:00 매시 정각 실행 기준.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta

from news_pulse.db.store import SqliteStore

logger = logging.getLogger(__name__)

# launchd 스케줄 — 실행 허용 시간대 (09~23시)
_SCHEDULE_START_HOUR = 9
_SCHEDULE_END_HOUR = 23


def _expected_slots(last_run: datetime, now: datetime) -> list[datetime]:
    """last_run 이후 now까지 실행되어야 했던 시간대 목록을 반환한다."""
    slots: list[datetime] = []
    # last_run 직후 첫 번째 예정 시각부터 시작
    candidate = last_run.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
    while candidate <= now:
        if _SCHEDULE_START_HOUR <= candidate.hour <= _SCHEDULE_END_HOUR:
            slots.append(candidate)
        candidate += timedelta(hours=1)
    return slots


def detect_missed(store: SqliteStore, current_time: datetime) -> list[str]:
    """
    마지막 실행 이후 놓친 시간대를 감지하고 schedule_log에 기록한다.

    반환값: 놓친 시간대 문자열 목록 (ISO 형식).
    """
    try:
        latest = store.get_latest_run()
        if latest is None:
            return []
        run_at_raw = latest.get("run_at")
        if not isinstance(run_at_raw, str):
            return []
        last_run = datetime.fromisoformat(run_at_raw)
        missed_slots = _expected_slots(last_run, current_time)
        result: list[str] = []
        for slot in missed_slots:
            slot_str = slot.isoformat()
            store.log_scheduled(scheduled_at=slot_str, actual_at=None, status="missed")
            result.append(slot_str)
            logger.info("놓친 스케줄 감지: %s", slot_str)
        return result
    except Exception as exc:
        logger.warning("스케줄 누락 감지 실패: %s", exc)
        return []
