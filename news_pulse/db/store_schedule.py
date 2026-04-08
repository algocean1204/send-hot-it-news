"""
schedule_log 테이블 접근 메서드 모음.

SqliteStore의 launchd 스케줄 추적 관련 메서드를 별도 파일로 분리한다.
직접 사용하지 말고 SqliteStore를 통해 접근한다.
"""
from __future__ import annotations

import sqlite3

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None


def _row_to_dict(row: sqlite3.Row) -> dict[str, _SqliteVal]:
    """sqlite3.Row 객체를 일반 딕셔너리로 변환한다."""
    return dict(row)


def log_scheduled(
    conn: sqlite3.Connection,
    scheduled_at: str,
    actual_at: str | None,
    status: str,
) -> int:
    """
    스케줄 실행 기록을 삽입하고 삽입된 id를 반환한다.

    status 허용값: 'pending' | 'executed' | 'missed' | 'catchup'
    actual_at이 None이면 아직 실행되지 않은 예정 기록이다.
    """
    cursor = conn.execute(
        "INSERT INTO schedule_log (scheduled_at, actual_at, status) VALUES (?, ?, ?)",
        (scheduled_at, actual_at, status),
    )
    conn.commit()
    row_id = cursor.lastrowid
    if row_id is None:
        raise RuntimeError("INSERT 후 lastrowid가 None — schedule_log 삽입 실패")
    return row_id


def get_missed(
    conn: sqlite3.Connection, since_hours: int = 24
) -> list[dict[str, _SqliteVal]]:
    """최근 N시간 내 놓친(missed) 스케줄 목록을 반환한다."""
    rows = conn.execute(
        """
        SELECT * FROM schedule_log
        WHERE status = 'missed'
          AND scheduled_at >= datetime('now', ? || ' hours', 'localtime')
        ORDER BY scheduled_at DESC
        """,
        (f"-{since_hours}",),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def mark_executed(conn: sqlite3.Connection, schedule_id: int) -> None:
    """지정 스케줄 id를 실행 완료 상태로 갱신한다."""
    conn.execute(
        "UPDATE schedule_log SET status = 'executed', "
        "actual_at = datetime('now','localtime') WHERE id = ?",
        (schedule_id,),
    )
    conn.commit()
