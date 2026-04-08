"""
subscribers 테이블 접근 메서드 모음.

SqliteStore의 subscribers 관련 메서드를 별도 파일로 분리한다.
직접 사용하지 말고 SqliteStore를 통해 접근한다.
"""
from __future__ import annotations

import sqlite3

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None


def _row_to_dict(row: sqlite3.Row) -> dict[str, _SqliteVal]:
    """sqlite3.Row 객체를 일반 딕셔너리로 변환한다."""
    return dict(row)


def upsert_subscriber(
    conn: sqlite3.Connection,
    chat_id: int,
    username: str | None,
    first_name: str | None,
) -> None:
    """구독자 INSERT OR IGNORE. 이미 존재하면 username/first_name만 업데이트한다."""
    conn.execute(
        """
        INSERT INTO subscribers (chat_id, username, first_name)
        VALUES (?, ?, ?)
        ON CONFLICT(chat_id) DO UPDATE SET
            username   = excluded.username,
            first_name = excluded.first_name
        """,
        (chat_id, username, first_name),
    )
    conn.commit()


def update_subscriber_status(
    conn: sqlite3.Connection, chat_id: int, status: str
) -> None:
    """구독자 상태 변경 (pending -> approved / rejected)."""
    now_expr = "datetime('now','localtime')"
    if status == "approved":
        conn.execute(
            f"UPDATE subscribers SET status=?, approved_at={now_expr} WHERE chat_id=?",
            (status, chat_id),
        )
    elif status == "rejected":
        conn.execute(
            f"UPDATE subscribers SET status=?, rejected_at={now_expr} WHERE chat_id=?",
            (status, chat_id),
        )
    else:
        conn.execute(
            "UPDATE subscribers SET status=? WHERE chat_id=?", (status, chat_id)
        )
    conn.commit()


def get_approved_chat_ids(conn: sqlite3.Connection) -> list[int]:
    """승인된 구독자 chat_id 목록 반환 (TelegramSender용)."""
    rows = conn.execute(
        "SELECT chat_id FROM subscribers WHERE status = 'approved'"
    ).fetchall()
    return [r["chat_id"] for r in rows]


def get_subscribers_by_status(
    conn: sqlite3.Connection, status: str
) -> list[dict[str, _SqliteVal]]:
    """상태별 구독자 목록 조회 (Flutter 화면 3용)."""
    rows = conn.execute(
        "SELECT * FROM subscribers WHERE status = ? ORDER BY requested_at DESC",
        (status,),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def delete_subscriber(conn: sqlite3.Connection, chat_id: int) -> None:
    """구독자 삭제."""
    conn.execute("DELETE FROM subscribers WHERE chat_id = ?", (chat_id,))
    conn.commit()


def get_subscriber_counts(conn: sqlite3.Connection) -> dict[str, int]:
    """상태별 구독자 수 집계 (pending, approved, rejected)."""
    rows = conn.execute(
        "SELECT status, COUNT(*) as cnt FROM subscribers GROUP BY status"
    ).fetchall()
    result: dict[str, int] = {"pending": 0, "approved": 0, "rejected": 0}
    for r in rows:
        result[r["status"]] = r["cnt"]
    return result
