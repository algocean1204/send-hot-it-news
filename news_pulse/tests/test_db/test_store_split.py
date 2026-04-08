"""
SqliteStore 위임 검증 + 서브스토어 독립 테스트.

SqliteStore가 올바른 서브모듈에 위임하는지,
integrity_check/vacuum 공개 메서드, 컨텍스트 매니저 동작을 검증한다.
"""
from __future__ import annotations

import sqlite3

import pytest

from news_pulse.db.migrate import migrate
from news_pulse.db.store import SqliteStore


@pytest.fixture
def store(tmp_path) -> SqliteStore:
    """임시 DB 파일로 SqliteStore를 생성하는 픽스처."""
    db_path = str(tmp_path / "split_test.db")
    migrate(db_path)
    return SqliteStore(db_path)


@pytest.fixture(autouse=True)
def cleanup_store(store: SqliteStore):
    """테스트 종료 후 DB 연결을 닫는다."""
    yield
    store.close()


# -- integrity_check / vacuum 테스트 -- #

def test_integrity_check_ok(store: SqliteStore) -> None:
    """정상 DB에서 integrity_check()가 'ok'를 반환해야 한다."""
    result = store.integrity_check()
    assert result == "ok"


def test_vacuum_실행_성공(store: SqliteStore) -> None:
    """vacuum()이 예외 없이 실행되어야 한다."""
    store.vacuum()  # 예외가 발생하면 테스트가 실패한다


def test_get_db_size_양수(store: SqliteStore) -> None:
    """DB 파일이 존재하면 0보다 큰 크기를 반환해야 한다."""
    size = store.get_db_size()
    assert size > 0


# -- 컨텍스트 매니저 테스트 -- #

def test_context_manager(tmp_path) -> None:
    """with 문으로 사용 후 연결이 닫혀야 한다."""
    db_path = str(tmp_path / "ctx_test.db")
    migrate(db_path)

    with SqliteStore(db_path) as s:
        result = s.integrity_check()
        assert result == "ok"

    # close() 후에는 쿼리가 실패해야 한다
    with pytest.raises(Exception):
        s._conn.execute("SELECT 1")


# -- 서브스토어 위임 검증 -- #

def test_url_hash_exists_위임(store: SqliteStore) -> None:
    """url_hash_exists()가 store_processed 모듈에 올바르게 위임해야 한다."""
    assert store.url_hash_exists("nonexistent") is False
    store.insert_processed_item({
        "url_hash": "test_hash_split",
        "url": "https://split.com/1",
        "title": "Split Test",
        "source": "hackernews",
        "language": "en",
        "raw_content": None,
        "summary_ko": None,
        "tags": None,
        "upvotes": 0,
        "is_hot": 0,
        "pipeline_path": "apex",
        "processing_time_ms": 100,
        "telegram_sent": 0,
    })
    assert store.url_hash_exists("test_hash_split") is True


def test_subscriber_위임(store: SqliteStore) -> None:
    """subscriber 관련 메서드가 store_subscribers에 위임되어야 한다."""
    store.upsert_subscriber(99001, "splituser", "Split")
    rows = store.get_subscribers_by_status("pending")
    ids = [r["chat_id"] for r in rows]
    assert 99001 in ids

    store.update_subscriber_status(99001, "approved")
    approved = store.get_approved_chat_ids()
    assert 99001 in approved


def test_cleanup_old_data_트랜잭션_원자성(store: SqliteStore) -> None:
    """cleanup_old_data가 6개 DELETE를 단일 트랜잭션으로 실행해야 한다 (model_usage_log, schedule_log 추가)."""
    # 데이터가 없어도 트랜잭션이 정상 완료되어야 한다
    result = store.cleanup_old_data({
        "processed_items": 1,
        "run_history": 1,
        "error_log": 1,
        "health_check_results": 1,
        "model_usage_log": 90,
        "schedule_log": 30,
    })
    assert isinstance(result, dict)
    assert len(result) == 6
    # 모든 삭제 건수가 0 이상이어야 한다
    for count in result.values():
        assert count >= 0


def test_run_history_화이트리스트_검증(store: SqliteStore) -> None:
    """허용되지 않은 컬럼으로 update_run 시 ValueError가 발생해야 한다."""
    run_id = store.insert_run({
        "started_at": "2026-04-08 10:00:00",
        "status": "running",
        "memory_mode": "local_llm",
    })
    with pytest.raises(ValueError, match="허용되지 않은 컬럼"):
        store.update_run(run_id, {"invalid_column": "bad_value"})


def test_hot_news_nullable_FK(store: SqliteStore) -> None:
    """processed_item_id=None으로 hot_news 삽입이 가능해야 한다."""
    hot_id = store.insert_hot_news({
        "processed_item_id": None,
        "url": "https://example.com/nullable-fk",
        "title": "Nullable FK Test",
        "source": "hackernews",
        "summary_ko": "요약",
        "tags": None,
        "upvotes": 100,
        "hot_reason": "test",
    })
    assert hot_id > 0


def test_config_value_round_trip(store: SqliteStore) -> None:
    """set_config_value -> get_config_value 왕복 검증."""
    store.set_config_value("round_trip_key", "round_trip_value")
    assert store.get_config_value("round_trip_key") == "round_trip_value"

    # 덮어쓰기 검증
    store.set_config_value("round_trip_key", "updated_value")
    assert store.get_config_value("round_trip_key") == "updated_value"
