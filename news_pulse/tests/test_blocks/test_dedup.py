"""
Dedup 단위 테스트.

중복 URL 해시는 제거되고, 신규 항목만 NewsItem으로 반환됨을 검증한다.
"""
from __future__ import annotations

from datetime import datetime
from unittest.mock import MagicMock

from news_pulse.blocks.dedup import SqliteDedup
from news_pulse.models.news import RawItem


def _make_raw_item(url: str, source_id: str = "test") -> RawItem:
    """테스트용 RawItem을 생성한다."""
    import hashlib
    return RawItem(
        url=url,
        title=f"테스트: {url}",
        content="내용",
        source_id=source_id,
        fetched_at=datetime.now(),
        upvotes=None,
        published_at=None,
        url_hash=hashlib.sha256(url.encode()).hexdigest(),
    )


def test_filters_duplicate_items() -> None:
    """이미 존재하는 url_hash는 결과에서 제외되어야 한다."""
    mock_db = MagicMock()
    mock_db.url_hash_exists.side_effect = lambda h: h == _make_raw_item("http://dup.com").url_hash

    dedup = SqliteDedup(mock_db)
    items = [_make_raw_item("http://dup.com"), _make_raw_item("http://new.com")]
    result = dedup.filter_new(items)

    assert len(result) == 1
    assert result[0].url == "http://new.com"


def test_new_items_are_returned_as_news_items() -> None:
    """신규 항목은 NewsItem으로 변환되어 반환되어야 한다."""
    mock_db = MagicMock()
    mock_db.url_hash_exists.return_value = False

    dedup = SqliteDedup(mock_db)
    items = [_make_raw_item("http://new.com")]
    result = dedup.filter_new(items)

    assert len(result) == 1
    assert result[0].lang == ""  # LanguageDetector 전 단계 — 빈 문자열


def test_db_failure_returns_all_as_new() -> None:
    """DB 접근 실패 시 전체 아이템을 신규로 처리해야 한다."""
    mock_db = MagicMock()
    mock_db.url_hash_exists.side_effect = RuntimeError("DB 연결 실패")

    dedup = SqliteDedup(mock_db)
    items = [_make_raw_item("http://a.com"), _make_raw_item("http://b.com")]
    result = dedup.filter_new(items)

    assert len(result) == 2


def test_empty_input_returns_empty() -> None:
    """빈 입력에는 빈 리스트를 반환해야 한다."""
    mock_db = MagicMock()
    dedup = SqliteDedup(mock_db)
    result = dedup.filter_new([])
    assert result == []
