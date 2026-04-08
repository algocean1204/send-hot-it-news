"""
DataCleaner 테스트.

보관 기간 초과 데이터 삭제, VACUUM 주기 판단,
VACUUM 실패 시 무시 동작을 검증한다.
"""
from __future__ import annotations

from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch

import pytest

from news_pulse.blocks.data_cleaner import SqliteDataCleaner, _LAST_VACUUM_KEY
from news_pulse.models.config import Config


def _config() -> Config:
    """테스트용 Config 객체를 생성한다."""
    return Config(
        bot_token="tok", admin_chat_id="admin1",
        db_path="/tmp/cleaner.db", ollama_endpoint="http://localhost:11434",
        apex_model_name="apex", kanana_model_name="kanana",
        memory_threshold_gb=26.0,
    )


def test_clean_반환값_CleanupResult() -> None:
    """clean() 결과가 CleanupResult 타입이어야 한다."""
    db = MagicMock()
    db.cleanup_old_data.return_value = {
        "processed_items": 5, "run_history": 2,
        "error_log": 1, "health_check_results": 0,
    }
    db.get_config_value.return_value = None
    db.vacuum.return_value = None
    db.set_config_value.return_value = None

    cleaner = SqliteDataCleaner(db)
    result = cleaner.clean(_config())

    assert result.processed_items_deleted == 5
    assert result.run_history_deleted == 2
    assert result.error_log_deleted == 1
    assert result.health_check_deleted == 0
    assert isinstance(result.cleaned_at, datetime)


def test_vacuum_7일_이내_건너뛰기() -> None:
    """마지막 VACUUM이 7일 이내이면 VACUUM을 실행하지 않아야 한다."""
    db = MagicMock()
    db.cleanup_old_data.return_value = {
        "processed_items": 0, "run_history": 0,
        "error_log": 0, "health_check_results": 0,
    }
    # 1일 전에 VACUUM 실행한 기록
    recent = (datetime.now() - timedelta(days=1)).isoformat()
    db.get_config_value.return_value = recent

    cleaner = SqliteDataCleaner(db)
    cleaner.clean(_config())

    # VACUUM은 호출되지 않아야 한다
    db.vacuum.assert_not_called()


def test_vacuum_7일_초과_실행() -> None:
    """마지막 VACUUM이 8일 전이면 VACUUM을 실행해야 한다."""
    db = MagicMock()
    db.cleanup_old_data.return_value = {
        "processed_items": 0, "run_history": 0,
        "error_log": 0, "health_check_results": 0,
    }
    old = (datetime.now() - timedelta(days=8)).isoformat()
    db.get_config_value.return_value = old
    db.vacuum.return_value = None
    db.set_config_value.return_value = None

    cleaner = SqliteDataCleaner(db)
    cleaner.clean(_config())

    db.vacuum.assert_called_once()
    db.set_config_value.assert_called_once()


def test_vacuum_기록_없으면_실행() -> None:
    """VACUUM 기록이 None이면 첫 실행으로 간주해 VACUUM을 실행해야 한다."""
    db = MagicMock()
    db.cleanup_old_data.return_value = {
        "processed_items": 0, "run_history": 0,
        "error_log": 0, "health_check_results": 0,
    }
    db.get_config_value.return_value = None
    db.vacuum.return_value = None
    db.set_config_value.return_value = None

    cleaner = SqliteDataCleaner(db)
    cleaner.clean(_config())

    db.vacuum.assert_called_once()


def test_vacuum_실패시_예외_무시() -> None:
    """VACUUM 실행 중 예외가 발생해도 clean()은 정상 완료되어야 한다."""
    db = MagicMock()
    db.cleanup_old_data.return_value = {
        "processed_items": 0, "run_history": 0,
        "error_log": 0, "health_check_results": 0,
    }
    db.get_config_value.return_value = None
    db.vacuum.side_effect = RuntimeError("VACUUM 실패")

    cleaner = SqliteDataCleaner(db)
    # 예외가 전파되지 않아야 한다
    result = cleaner.clean(_config())
    assert result.processed_items_deleted == 0
