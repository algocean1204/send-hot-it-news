"""
SqliteStore 전체 메서드 테스트.

인메모리 DB(:memory:)를 사용하여 외부 파일 의존성 없이 테스트한다.
마이그레이션 멱등성, FK 제약조건, WAL 모드도 함께 검증한다.
"""
from __future__ import annotations

import pytest

from news_pulse.db.migrate import migrate
from news_pulse.db.store import SqliteStore


@pytest.fixture
def store(tmp_path) -> SqliteStore:
    """
    임시 파일 경로에 마이그레이션 후 SqliteStore를 반환하는 픽스처.

    :memory:는 migrate() 함수와 SqliteStore가 서로 다른 연결을 사용하므로
    tmp_path 기반 파일 경로를 사용한다.
    """
    db_path = str(tmp_path / "test.db")
    migrate(db_path)
    return SqliteStore(db_path)


@pytest.fixture(autouse=True)
def cleanup_store(store: SqliteStore):
    """픽스처: 테스트 종료 후 DB 연결을 닫는다."""
    yield
    store.close()


# ------------------------------------------------------------------ #
#  마이그레이션 테스트
# ------------------------------------------------------------------ #

class TestMigration:
    """마이그레이션 동작을 검증한다."""

    def test_멱등성_2회_실행(self, tmp_path) -> None:
        """동일 경로에 migrate()를 두 번 실행해도 에러가 없어야 한다."""
        db_path = str(tmp_path / "idempotent.db")
        migrate(db_path)
        migrate(db_path)  # 두 번째 실행 — IF NOT EXISTS / INSERT OR IGNORE 보장

    def test_WAL_모드_확인(self, store: SqliteStore) -> None:
        """journal_mode가 wal로 설정되어 있는지 확인한다."""
        row = store._conn.execute("PRAGMA journal_mode").fetchone()
        assert row[0].lower() == "wal"

    def test_FK_활성화_확인(self, store: SqliteStore) -> None:
        """foreign_keys PRAGMA가 1(ON)인지 확인한다."""
        row = store._conn.execute("PRAGMA foreign_keys").fetchone()
        assert row[0] == 1

    def test_테이블_수_확인(self, store: SqliteStore) -> None:
        """11개 사용자 정의 테이블이 모두 생성되어 있는지 확인한다 (신규 4개 추가)."""
        row = store._conn.execute(
            "SELECT COUNT(*) as cnt FROM sqlite_master "
            "WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        ).fetchone()
        assert row["cnt"] == 11

    def test_시드_filter_config_건수(self, store: SqliteStore) -> None:
        """시드 데이터 22건이 filter_config에 삽입되어 있는지 확인한다 (theme_mode 1건 추가)."""
        row = store._conn.execute(
            "SELECT COUNT(*) as cnt FROM filter_config"
        ).fetchone()
        assert row["cnt"] == 22

    def test_시드_subscribers_관리자(self, store: SqliteStore) -> None:
        """시드 구독자(관리자 1건)가 삽입되어 있는지 확인한다."""
        row = store._conn.execute(
            "SELECT * FROM subscribers WHERE is_admin = 1"
        ).fetchone()
        assert row is not None
        assert row["status"] == "approved"


# ------------------------------------------------------------------ #
#  processed_items 테스트
# ------------------------------------------------------------------ #

class TestProcessedItems:
    """processed_items 관련 메서드 테스트."""

    def _sample_item(self, suffix: str = "1") -> dict:
        """테스트용 processed_item 딕셔너리를 반환한다."""
        return {
            "url_hash": f"hash_{suffix}",
            "url": f"https://example.com/post/{suffix}",
            "title": f"Test Article {suffix}",
            "source": "hackernews",
            "language": "en",
            "raw_content": "Some content",
            "summary_ko": "한국어 요약",
            "tags": '["AI","LLM"]',
            "upvotes": 150,
            "is_hot": 0,
            "pipeline_path": "apex",
            "processing_time_ms": 1200,
            "telegram_sent": 0,
        }

    def test_url_hash_존재_없음(self, store: SqliteStore) -> None:
        """삽입 전에는 url_hash_exists()가 False를 반환해야 한다."""
        assert store.url_hash_exists("nonexistent_hash") is False

    def test_삽입_후_hash_존재(self, store: SqliteStore) -> None:
        """삽입 후 url_hash_exists()가 True를 반환해야 한다."""
        store.insert_processed_item(self._sample_item("a"))
        assert store.url_hash_exists("hash_a") is True

    def test_삽입_id_반환(self, store: SqliteStore) -> None:
        """insert_processed_item()이 양수 id를 반환해야 한다."""
        item_id = store.insert_processed_item(self._sample_item("b"))
        assert isinstance(item_id, int)
        assert item_id > 0

    def test_부분_업데이트(self, store: SqliteStore) -> None:
        """update_processed_item()으로 summary_ko를 업데이트한다."""
        item_id = store.insert_processed_item(self._sample_item("c"))
        store.update_processed_item(item_id, {"summary_ko": "업데이트된 요약", "telegram_sent": 1})
        row = store._conn.execute(
            "SELECT summary_ko, telegram_sent FROM processed_items WHERE id=?", (item_id,)
        ).fetchone()
        assert row["summary_ko"] == "업데이트된 요약"
        assert row["telegram_sent"] == 1

    def test_날짜별_조회(self, store: SqliteStore) -> None:
        """get_processed_items_by_date()가 오늘 날짜 기준으로 조회하는지 확인한다."""
        store.insert_processed_item(self._sample_item("d"))
        import datetime
        today = datetime.date.today().isoformat()
        results = store.get_processed_items_by_date(today)
        # 오늘 삽입한 아이템이 포함되어야 한다
        assert len(results) >= 1
        assert all(isinstance(r, dict) for r in results)

    def test_오늘_전송_건수(self, store: SqliteStore) -> None:
        """get_today_sent_count()가 telegram_sent=1인 오늘 아이템 수를 반환한다."""
        item = self._sample_item("e")
        item_id = store.insert_processed_item(item)
        # 전송 전: 0
        assert store.get_today_sent_count() == 0
        # 전송 후: 1
        store.update_processed_item(item_id, {"telegram_sent": 1})
        assert store.get_today_sent_count() == 1


# ------------------------------------------------------------------ #
#  hot_news 테스트
# ------------------------------------------------------------------ #

class TestHotNews:
    """hot_news 관련 메서드 테스트."""

    def _insert_parent(self, store: SqliteStore) -> int:
        """FK 부모(processed_items) 레코드를 삽입하고 id를 반환한다."""
        return store.insert_processed_item({
            "url_hash": "hot_parent_hash",
            "url": "https://example.com/hot",
            "title": "Hot Article",
            "source": "hackernews",
            "language": "en",
            "raw_content": None,
            "summary_ko": "핫뉴스 요약",
            "tags": '["hot"]',
            "upvotes": 500,
            "is_hot": 1,
            "pipeline_path": "apex",
            "processing_time_ms": 800,
            "telegram_sent": 1,
        })

    def test_삽입_및_조회(self, store: SqliteStore) -> None:
        """핫뉴스 삽입 후 목록에서 조회할 수 있어야 한다."""
        parent_id = self._insert_parent(store)
        hot_id = store.insert_hot_news({
            "processed_item_id": parent_id,
            "url": "https://example.com/hot",
            "title": "Hot Article",
            "source": "hackernews",
            "summary_ko": "핫뉴스 요약",
            "tags": '["hot"]',
            "upvotes": 500,
            "hot_reason": "upvote_auto",
        })
        assert hot_id > 0
        items = store.get_hot_news_list()
        assert len(items) == 1
        assert items[0]["hot_reason"] == "upvote_auto"

    def test_FK_위반_실패(self, store: SqliteStore) -> None:
        """존재하지 않는 processed_item_id로 hot_news 삽입 시 FK 에러가 발생해야 한다."""
        import sqlite3
        with pytest.raises(sqlite3.IntegrityError):
            store.insert_hot_news({
                "processed_item_id": 99999,  # 존재하지 않는 id
                "url": "https://example.com/fake",
                "title": "Fake",
                "source": "hackernews",
                "summary_ko": "가짜 요약",
                "tags": None,
                "upvotes": 0,
                "hot_reason": "manual",
            })

    def test_삭제(self, store: SqliteStore) -> None:
        """delete_hot_news_by_processed_id()로 삭제 후 목록이 비어야 한다."""
        parent_id = self._insert_parent(store)
        store.insert_hot_news({
            "processed_item_id": parent_id,
            "url": "https://example.com/hot",
            "title": "Hot",
            "source": "hackernews",
            "summary_ko": "요약",
            "tags": None,
            "upvotes": 300,
            "hot_reason": "upvote_auto",
        })
        store.delete_hot_news_by_processed_id(parent_id)
        assert store.get_hot_news_list() == []


# ------------------------------------------------------------------ #
#  subscribers 테스트
# ------------------------------------------------------------------ #

class TestSubscribers:
    """subscribers 관련 메서드 테스트."""

    def test_upsert_신규(self, store: SqliteStore) -> None:
        """신규 구독자 upsert 후 pending 상태로 존재해야 한다."""
        store.upsert_subscriber(111222333, "newuser", "New")
        rows = store.get_subscribers_by_status("pending")
        chat_ids = [r["chat_id"] for r in rows]
        assert 111222333 in chat_ids

    def test_upsert_중복_업데이트(self, store: SqliteStore) -> None:
        """같은 chat_id로 다시 upsert 시 username이 업데이트되어야 한다."""
        store.upsert_subscriber(111222333, "oldname", "Old")
        store.upsert_subscriber(111222333, "newname", "New")
        rows = store.get_subscribers_by_status("pending")
        matched = [r for r in rows if r["chat_id"] == 111222333]
        assert matched[0]["username"] == "newname"

    def test_상태_변경_승인(self, store: SqliteStore) -> None:
        """pending -> approved 상태 변경 후 approved 목록에 포함되어야 한다."""
        store.upsert_subscriber(555666777, "approveuser", "User")
        store.update_subscriber_status(555666777, "approved")
        approved_ids = store.get_approved_chat_ids()
        assert 555666777 in approved_ids

    def test_승인된_chat_ids(self, store: SqliteStore) -> None:
        """시드 데이터의 관리자(approved)가 get_approved_chat_ids()에 포함되어야 한다."""
        approved = store.get_approved_chat_ids()
        assert 123456789 in approved  # 시드 데이터 관리자

    def test_삭제(self, store: SqliteStore) -> None:
        """삭제 후 해당 chat_id가 조회되지 않아야 한다."""
        store.upsert_subscriber(999888777, "deluser", "Del")
        store.delete_subscriber(999888777)
        all_rows = store.get_subscribers_by_status("pending")
        assert all(r["chat_id"] != 999888777 for r in all_rows)

    def test_건수_집계(self, store: SqliteStore) -> None:
        """get_subscriber_counts()가 상태별 카운트를 올바르게 반환해야 한다."""
        counts = store.get_subscriber_counts()
        # 시드 데이터로 approved 1명 존재
        assert "approved" in counts
        assert counts["approved"] >= 1


# ------------------------------------------------------------------ #
#  run_history 테스트
# ------------------------------------------------------------------ #

class TestRunHistory:
    """run_history 관련 메서드 테스트."""

    def _sample_run(self) -> dict:
        return {
            "started_at": "2026-04-08 10:00:00",
            "status": "running",
            "memory_mode": "local_llm",
        }

    def test_삽입_및_최근_조회(self, store: SqliteStore) -> None:
        """삽입 후 get_latest_run()이 해당 레코드를 반환해야 한다."""
        run_id = store.insert_run(self._sample_run())
        latest = store.get_latest_run()
        assert latest is not None
        assert latest["id"] == run_id

    def test_업데이트(self, store: SqliteStore) -> None:
        """update_run()으로 상태와 건수를 업데이트한다."""
        run_id = store.insert_run(self._sample_run())
        store.update_run(run_id, {
            "status": "success",
            "sent_count": 8,
            "finished_at": "2026-04-08 10:01:00",
        })
        latest = store.get_latest_run()
        assert latest["status"] == "success"
        assert latest["sent_count"] == 8

    def test_이력_목록(self, store: SqliteStore) -> None:
        """get_run_history()가 리스트를 반환해야 한다."""
        store.insert_run(self._sample_run())
        history = store.get_run_history(limit=10)
        assert isinstance(history, list)
        assert len(history) >= 1


# ------------------------------------------------------------------ #
#  error_log 테스트
# ------------------------------------------------------------------ #

class TestErrorLog:
    """error_log 관련 메서드 테스트."""

    def test_삽입_및_조회(self, store: SqliteStore) -> None:
        """에러 삽입 후 get_recent_errors()에서 조회되어야 한다."""
        store.insert_error({
            "run_id": None,
            "severity": "error",
            "module": "Fetcher",
            "message": "Connection timeout",
            "traceback": None,
        })
        errors = store.get_recent_errors(limit=5)
        assert len(errors) >= 1
        assert errors[0]["module"] == "Fetcher"

    def test_심각도별_조회(self, store: SqliteStore) -> None:
        """get_errors_by_severity()가 해당 심각도만 반환해야 한다."""
        store.insert_error({
            "run_id": None,
            "severity": "critical",
            "module": "TelegramSender",
            "message": "API key invalid",
            "traceback": "Traceback...",
        })
        criticals = store.get_errors_by_severity("critical")
        assert all(e["severity"] == "critical" for e in criticals)


# ------------------------------------------------------------------ #
#  filter_config 테스트
# ------------------------------------------------------------------ #

class TestFilterConfig:
    """filter_config 관련 메서드 테스트."""

    def test_시드_값_조회(self, store: SqliteStore) -> None:
        """시드에서 삽입된 tier3_hn_threshold 값이 '50'이어야 한다.
        (P2-9 수정: ConfigLoader가 읽는 키 이름으로 통일)"""
        value = store.get_config_value("tier3_hn_threshold")
        assert value == "50"

    def test_없는_키_none_반환(self, store: SqliteStore) -> None:
        """존재하지 않는 키는 None을 반환해야 한다."""
        assert store.get_config_value("nonexistent_key") is None

    def test_set_새_값(self, store: SqliteStore) -> None:
        """새 키를 set_config_value()로 저장 후 조회할 수 있어야 한다."""
        store.set_config_value("new_setting", "new_value")
        assert store.get_config_value("new_setting") == "new_value"

    def test_set_기존_값_덮어쓰기(self, store: SqliteStore) -> None:
        """기존 키를 다른 값으로 업데이트할 수 있어야 한다."""
        store.set_config_value("hn_min_points", "100")
        assert store.get_config_value("hn_min_points") == "100"

    def test_전체_조회(self, store: SqliteStore) -> None:
        """get_all_config()가 19건 이상의 딕셔너리를 반환해야 한다."""
        config = store.get_all_config()
        assert isinstance(config, dict)
        assert len(config) >= 19


# ------------------------------------------------------------------ #
#  health_check_results 테스트
# ------------------------------------------------------------------ #

class TestHealthCheckResults:
    """health_check_results 관련 메서드 테스트."""

    def test_삽입_및_최신_조회(self, store: SqliteStore) -> None:
        """삽입 후 get_latest_health_checks()에서 조회되어야 한다."""
        store.insert_health_check({
            "check_type": "ollama",
            "target": "apex-i-compact",
            "status": "ok",
            "message": "응답 정상",
            "response_time_ms": 150,
        })
        results = store.get_latest_health_checks()
        assert len(results) >= 1
        assert results[0]["check_type"] == "ollama"

    def test_최신_세트만_반환(self, store: SqliteStore) -> None:
        """같은 check_type+target 조합은 최신 1건만 반환되어야 한다."""
        for msg in ["첫 번째", "두 번째", "세 번째"]:
            store.insert_health_check({
                "check_type": "source",
                "target": "https://geeknews.kr/rss",
                "status": "ok",
                "message": msg,
                "response_time_ms": 200,
            })
        results = store.get_latest_health_checks()
        source_checks = [r for r in results if r["check_type"] == "source"]
        assert len(source_checks) == 1
        assert source_checks[0]["message"] == "세 번째"


# ------------------------------------------------------------------ #
#  cleanup_old_data 테스트
# ------------------------------------------------------------------ #

class TestCleanup:
    """cleanup_old_data() 테스트."""

    def test_삭제_건수_반환(self, store: SqliteStore) -> None:
        """cleanup_old_data()가 테이블별 삭제 건수 딕셔너리를 반환해야 한다."""
        result = store.cleanup_old_data({
            "processed_items": 30,
            "run_history": 90,
            "error_log": 30,
            "health_check_results": 7,
        })
        assert "processed_items" in result
        assert "run_history" in result
        assert "error_log" in result
        assert "health_check_results" in result
        # 방금 삽입한 데이터는 보관 기간 내이므로 0건 삭제
        assert result["processed_items"] == 0


# ------------------------------------------------------------------ #
#  통계 테스트
# ------------------------------------------------------------------ #

class TestStats:
    """get_source_stats(), get_pipeline_stats() 테스트."""

    def test_source_stats_빈_결과(self, store: SqliteStore) -> None:
        """데이터 없을 때 빈 리스트를 반환해야 한다."""
        result = store.get_source_stats(days=7)
        assert isinstance(result, list)

    def test_pipeline_stats_빈_결과(self, store: SqliteStore) -> None:
        """데이터 없을 때 빈 리스트를 반환해야 한다."""
        result = store.get_pipeline_stats(days=7)
        assert isinstance(result, list)
