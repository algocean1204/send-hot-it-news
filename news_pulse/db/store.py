"""
SqliteStore: DB 접근 레이어 (메인 진입점).

모든 블럭이 이 클래스를 통해 DB에 접근한다.
구현은 store_processed/hot_news/subscribers/admin/cleanup 및
신규 5개 서브스토어(whitelist/model_usage/schedule/prompts/analytics)로 분리 위임한다.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path
from types import TracebackType

from news_pulse.db import store_admin as _admin
from news_pulse.db import store_analytics as _analytics
from news_pulse.db import store_cleanup as _cleanup
from news_pulse.db import store_hot_news as _hot
from news_pulse.db import store_model_usage as _model_usage
from news_pulse.db import store_processed as _processed
from news_pulse.db import store_prompts as _prompts
from news_pulse.db import store_schedule as _schedule
from news_pulse.db import store_subscribers as _subs
from news_pulse.db import store_whitelist as _whitelist

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None
# 행 딕셔너리 타입 별칭 (반복 제거)
_Row = dict[str, _SqliteVal]


class SqliteStore:
    """SQLite DB 접근 유틸리티 클래스. Context manager 지원, WAL 모드 + FK ON."""

    def __init__(self, db_path: str) -> None:
        """DB 연결 + PRAGMA 4개 설정. WAL 모드, FK ON, busy_timeout=5000ms."""
        self._db_path = db_path
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(db_path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._apply_pragmas()

    def _apply_pragmas(self) -> None:
        """PRAGMA 초기화. 연결 시 반드시 실행해야 하는 DB 수준 설정."""
        cur = self._conn.cursor()
        cur.execute("PRAGMA journal_mode=WAL")
        cur.execute("PRAGMA busy_timeout=5000")
        cur.execute("PRAGMA foreign_keys=ON")
        cur.execute("PRAGMA synchronous=NORMAL")
        self._conn.commit()

    def close(self) -> None:
        """연결 종료."""
        self._conn.close()

    def __enter__(self) -> SqliteStore:
        return self

    def __exit__(self, exc_type: type[BaseException] | None, exc_val: BaseException | None, exc_tb: TracebackType | None) -> None:
        self.close()

    def get_db_size(self) -> int:
        """DB 파일 크기를 바이트로 반환한다."""
        p = Path(self._db_path)
        return p.stat().st_size if p.exists() else 0

    # --- store_cleanup 위임 ---
    def integrity_check(self) -> str: return _cleanup.integrity_check(self._conn)
    def vacuum(self) -> None: _cleanup.vacuum(self._conn)
    def cleanup_old_data(self, retention_days: dict[str, int]) -> dict[str, int]: return _cleanup.cleanup_old_data(self._conn, retention_days)
    def get_source_stats(self, days: int = 7) -> list[_Row]: return _cleanup.get_source_stats(self._conn, days)
    def get_pipeline_stats(self, days: int = 7) -> list[_Row]: return _cleanup.get_pipeline_stats(self._conn, days)

    # --- store_processed 위임 ---
    def url_hash_exists(self, url_hash: str) -> bool: return _processed.url_hash_exists(self._conn, url_hash)
    def insert_processed_item(self, item: _Row) -> int: return _processed.insert_processed_item(self._conn, item)
    def update_processed_item(self, item_id: int, updates: _Row) -> None: _processed.update_processed_item(self._conn, item_id, updates)
    def get_processed_items_by_date(self, date_str: str) -> list[_Row]: return _processed.get_processed_items_by_date(self._conn, date_str)
    def get_today_sent_count(self) -> int: return _processed.get_today_sent_count(self._conn)
    def mark_as_read(self, item_id: int) -> None: _processed.mark_as_read(self._conn, item_id)
    def get_unread_count(self) -> int: return _processed.get_unread_count(self._conn)

    # --- store_hot_news 위임 ---
    def insert_hot_news(self, hot: _Row) -> int: return _hot.insert_hot_news(self._conn, hot)
    def delete_hot_news_by_processed_id(self, processed_item_id: int) -> None: _hot.delete_hot_news_by_processed_id(self._conn, processed_item_id)
    def get_hot_news_list(self, limit: int = 50) -> list[_Row]: return _hot.get_hot_news_list(self._conn, limit)

    # --- store_subscribers 위임 ---
    def upsert_subscriber(self, chat_id: int, username: str | None, first_name: str | None) -> None: _subs.upsert_subscriber(self._conn, chat_id, username, first_name)
    def update_subscriber_status(self, chat_id: int, status: str) -> None: _subs.update_subscriber_status(self._conn, chat_id, status)
    def get_approved_chat_ids(self) -> list[int]: return _subs.get_approved_chat_ids(self._conn)
    def get_subscribers_by_status(self, status: str) -> list[_Row]: return _subs.get_subscribers_by_status(self._conn, status)
    def delete_subscriber(self, chat_id: int) -> None: _subs.delete_subscriber(self._conn, chat_id)
    def get_subscriber_counts(self) -> dict[str, int]: return _subs.get_subscriber_counts(self._conn)

    # --- store_admin 위임 ---
    def insert_run(self, run: _Row) -> int: return _admin.insert_run(self._conn, run)
    def update_run(self, run_id: int, updates: _Row) -> None: _admin.update_run(self._conn, run_id, updates)
    def get_latest_run(self) -> _Row | None: return _admin.get_latest_run(self._conn)
    def get_run_history(self, limit: int = 50) -> list[_Row]: return _admin.get_run_history(self._conn, limit)
    def insert_error(self, error: _Row) -> None: _admin.insert_error(self._conn, error)
    def get_recent_errors(self, limit: int = 10) -> list[_Row]: return _admin.get_recent_errors(self._conn, limit)
    def get_errors_by_severity(self, severity: str) -> list[_Row]: return _admin.get_errors_by_severity(self._conn, severity)
    def get_config_value(self, key: str) -> str | None: return _admin.get_config_value(self._conn, key)
    def set_config_value(self, key: str, value: str) -> None: _admin.set_config_value(self._conn, key, value)
    def get_all_config(self) -> dict[str, str]: return _admin.get_all_config(self._conn)
    def insert_health_check(self, check: _Row) -> None: _admin.insert_health_check(self._conn, check)
    def get_latest_health_checks(self) -> list[_Row]: return _admin.get_latest_health_checks(self._conn)

    # --- 신규: store_whitelist 위임 ---
    def get_whitelist_all(self) -> list[_Row]: return _whitelist.get_all(self._conn)
    def add_whitelist_keyword(self, keyword: str) -> int: return _whitelist.add(self._conn, keyword)
    def delete_whitelist_keyword(self, keyword_id: int) -> None: _whitelist.delete(self._conn, keyword_id)
    def get_whitelist_keywords_set(self) -> set[str]: return _whitelist.get_keywords_set(self._conn)

    # --- 신규: store_model_usage 위임 ---
    def log_model_usage(self, run_id: int | None, processed_item_id: int | None, model_name: str, task_type: str, latency_ms: int, input_tokens: int | None, success: int) -> int:
        return _model_usage.log_usage(self._conn, run_id, processed_item_id, model_name, task_type, latency_ms, input_tokens, success)
    def get_model_usage_by_date_range(self, start: str, end: str) -> list[_Row]: return _model_usage.get_by_date_range(self._conn, start, end)
    def get_avg_latency_by_model(self, days: int = 30) -> list[_Row]: return _model_usage.get_avg_latency_by_model(self._conn, days)

    # --- 신규: store_schedule 위임 ---
    def log_scheduled(self, scheduled_at: str, actual_at: str | None, status: str) -> int: return _schedule.log_scheduled(self._conn, scheduled_at, actual_at, status)
    def get_missed_schedules(self, since_hours: int = 24) -> list[_Row]: return _schedule.get_missed(self._conn, since_hours)
    def mark_schedule_executed(self, schedule_id: int) -> None: _schedule.mark_executed(self._conn, schedule_id)

    # --- 신규: store_prompts 위임 ---
    def get_active_prompt(self, prompt_type: str) -> _Row | None: return _prompts.get_active(self._conn, prompt_type)
    def create_prompt_version(self, prompt_type: str, content: str) -> int: return _prompts.create_version(self._conn, prompt_type, content)
    def get_all_prompt_versions(self, prompt_type: str) -> list[_Row]: return _prompts.get_all(self._conn, prompt_type)
    def activate_prompt_version(self, version_id: int) -> None: _prompts.activate(self._conn, version_id)

    # --- 신규: store_analytics 위임 ---
    def get_filtered_word_frequency(self, days: int = 30, limit: int = 20) -> list[_Row]: return _analytics.get_filtered_word_frequency(self._conn, days, limit)
    def get_pass_rate_by_source(self, days: int = 30) -> list[_Row]: return _analytics.get_pass_rate_by_source(self._conn, days)
    def get_upvote_distribution(self, source_id: str, days: int = 30) -> list[_Row]: return _analytics.get_upvote_distribution(self._conn, source_id, days)
