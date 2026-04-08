"""
processed_items 테이블 접근 메서드 모음.

SqliteStore의 processed_items 관련 메서드를 별도 파일로 분리한다.
직접 사용하지 말고 SqliteStore를 통해 접근한다.
"""
from __future__ import annotations

import sqlite3

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None


def _row_to_dict(row: sqlite3.Row) -> dict[str, _SqliteVal]:
    """sqlite3.Row 객체를 일반 딕셔너리로 변환한다."""
    return dict(row)


def url_hash_exists(conn: sqlite3.Connection, url_hash: str) -> bool:
    """URL 해시 존재 여부 확인 (Dedup 중복 체크용)."""
    row = conn.execute(
        "SELECT 1 FROM processed_items WHERE url_hash = ?", (url_hash,)
    ).fetchone()
    return row is not None


def insert_processed_item(
    conn: sqlite3.Connection, item: dict[str, _SqliteVal]
) -> int:
    """뉴스 아이템 삽입. 삽입된 row id를 반환한다."""
    cursor = conn.execute(
        """
        INSERT INTO processed_items
            (url_hash, url, title, source, language, raw_content,
             summary_ko, tags, upvotes, is_hot, pipeline_path,
             processing_time_ms, telegram_sent)
        VALUES
            (:url_hash, :url, :title, :source, :language, :raw_content,
             :summary_ko, :tags, :upvotes, :is_hot, :pipeline_path,
             :processing_time_ms, :telegram_sent)
        """,
        item,
    )
    conn.commit()
    row_id = cursor.lastrowid
    if row_id is None:
        raise RuntimeError("INSERT 후 lastrowid가 None — processed_items 삽입 실패")
    return row_id


# 허용된 컬럼 이름 화이트리스트 (SQL 인젝션 방지)
# is_read / summarizer_model / translator_model / prompt_version_id: 신규 컬럼 추가
_PROCESSED_ITEM_COLUMNS = frozenset({
    "summary_ko", "is_hot", "telegram_sent", "pipeline_path",
    "processing_time_ms", "tags", "language", "raw_content",
    "is_read", "summarizer_model", "translator_model", "prompt_version_id",
})


def update_processed_item(
    conn: sqlite3.Connection, item_id: int, updates: dict[str, _SqliteVal]
) -> None:
    """뉴스 아이템 부분 업데이트 (컬럼명 화이트리스트 검증 포함)."""
    if not updates:
        return
    # 허용되지 않은 컬럼명이 있으면 즉시 거부
    invalid = set(updates.keys()) - _PROCESSED_ITEM_COLUMNS
    if invalid:
        raise ValueError(f"허용되지 않은 컬럼: {invalid}")
    set_clause = ", ".join(f"{k} = :{k}" for k in updates)
    updates["_id"] = item_id
    conn.execute(
        f"UPDATE processed_items SET {set_clause} WHERE id = :_id", updates
    )
    conn.commit()


def get_processed_items_by_date(
    conn: sqlite3.Connection, date_str: str
) -> list[dict[str, _SqliteVal]]:
    """날짜별(YYYY-MM-DD) 뉴스 아이템 조회 (Flutter 화면 2용)."""
    rows = conn.execute(
        "SELECT * FROM processed_items WHERE date(created_at) = ? ORDER BY created_at DESC",
        (date_str,),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def get_today_sent_count(conn: sqlite3.Connection) -> int:
    """오늘 전송 건수 조회 (Flutter 화면 1 홈 화면용)."""
    row = conn.execute(
        """
        SELECT COUNT(*) as cnt FROM processed_items
        WHERE telegram_sent = 1 AND date(created_at) = date('now', 'localtime')
        """
    ).fetchone()
    return row["cnt"] if row else 0


def mark_as_read(conn: sqlite3.Connection, item_id: int) -> None:
    """뉴스 아이템을 읽음 상태로 표시한다 (Flutter 상세 보기 진입 시 호출)."""
    conn.execute(
        "UPDATE processed_items SET is_read = 1 WHERE id = ?", (item_id,)
    )
    conn.commit()


def get_unread_count(conn: sqlite3.Connection) -> int:
    """미읽음 아이템 수를 반환한다 (Flutter 홈 화면 배지용)."""
    row = conn.execute(
        "SELECT COUNT(*) AS cnt FROM processed_items WHERE is_read = 0"
    ).fetchone()
    return row["cnt"] if row else 0
