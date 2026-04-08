"""
hot_news 테이블 접근 메서드 모음.

SqliteStore의 hot_news 관련 메서드를 별도 파일로 분리한다.
직접 사용하지 말고 SqliteStore를 통해 접근한다.
"""
from __future__ import annotations

import sqlite3

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None


def _row_to_dict(row: sqlite3.Row) -> dict[str, _SqliteVal]:
    """sqlite3.Row 객체를 일반 딕셔너리로 변환한다."""
    return dict(row)


def insert_hot_news(conn: sqlite3.Connection, hot: dict[str, _SqliteVal]) -> int:
    """핫뉴스 삽입. 삽입된 row id를 반환한다."""
    cursor = conn.execute(
        """
        INSERT INTO hot_news
            (processed_item_id, url, title, source, summary_ko, tags, upvotes, hot_reason)
        VALUES
            (:processed_item_id, :url, :title, :source, :summary_ko, :tags, :upvotes, :hot_reason)
        """,
        hot,
    )
    conn.commit()
    row_id = cursor.lastrowid
    if row_id is None:
        raise RuntimeError("INSERT 후 lastrowid가 None — hot_news 삽입 실패")
    return row_id


def delete_hot_news_by_processed_id(
    conn: sqlite3.Connection, processed_item_id: int
) -> None:
    """핫뉴스 삭제 (수동 핫뉴스 토글 해제 시 사용)."""
    conn.execute(
        "DELETE FROM hot_news WHERE processed_item_id = ?", (processed_item_id,)
    )
    conn.commit()


def get_hot_news_list(
    conn: sqlite3.Connection, limit: int = 50
) -> list[dict[str, _SqliteVal]]:
    """핫뉴스 목록 조회 (최신순 내림차순)."""
    rows = conn.execute(
        "SELECT * FROM hot_news ORDER BY created_at DESC LIMIT ?", (limit,)
    ).fetchall()
    return [_row_to_dict(r) for r in rows]
