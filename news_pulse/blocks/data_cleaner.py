"""
블럭 16 — DataCleaner.

보관 기간이 지난 데이터를 삭제한다.
hot_news는 영구 보관이므로 정리 대상에서 제외한다.
VACUUM은 성능 고려로 주 1회만 실행한다.
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import Protocol

from news_pulse.db.store import SqliteStore
from news_pulse.models.config import Config
from news_pulse.models.pipeline import CleanupResult

logger = logging.getLogger(__name__)

# VACUUM 실행 간격 (초) — 주 1회
_VACUUM_INTERVAL_SECONDS = 7 * 24 * 3600
# filter_config에서 마지막 VACUUM 시각 저장 키
_LAST_VACUUM_KEY = "last_vacuum_at"


class DataCleanerProtocol(Protocol):
    """DataCleaner 인터페이스 정의."""

    def clean(self, config: Config) -> CleanupResult: ...


class SqliteDataCleaner:
    """보관 기간이 지난 데이터를 삭제하는 구현체."""

    def __init__(self, db: SqliteStore) -> None:
        """db: DELETE 쿼리 실행용 SqliteStore."""
        self._db = db

    def clean(self, config: Config) -> CleanupResult:
        """각 테이블에서 보관 기간 초과 데이터를 삭제한다."""
        retention = {
            "processed_items": config.processed_items_retention_days,
            "run_history": config.run_history_retention_days,
            "error_log": config.error_log_retention_days,
            "health_check_results": config.health_check_retention_days,
        }
        deleted = self._db.cleanup_old_data(retention)
        self._maybe_vacuum()
        return CleanupResult(
            processed_items_deleted=deleted.get("processed_items", 0),
            run_history_deleted=deleted.get("run_history", 0),
            error_log_deleted=deleted.get("error_log", 0),
            health_check_deleted=deleted.get("health_check_results", 0),
            cleaned_at=datetime.now(),
        )

    def _maybe_vacuum(self) -> None:
        """마지막 VACUUM으로부터 7일이 지났으면 VACUUM을 실행한다."""
        try:
            last_raw = self._db.get_config_value(_LAST_VACUUM_KEY)
            if last_raw:
                last_dt = datetime.fromisoformat(last_raw)
                elapsed = (datetime.now() - last_dt).total_seconds()
                if elapsed < _VACUUM_INTERVAL_SECONDS:
                    return
            # _conn 직접 접근 금지 — vacuum() 공개 메서드 사용
            self._db.vacuum()
            self._db.set_config_value(_LAST_VACUUM_KEY, datetime.now().isoformat())
            logger.info("VACUUM 실행 완료")
        except Exception as exc:
            logger.warning("VACUUM 실행 실패 (무시): %s", exc)
