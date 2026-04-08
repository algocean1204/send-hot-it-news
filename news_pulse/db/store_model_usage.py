"""
model_usage_log 테이블 접근 메서드 모음.

SqliteStore의 모델 사용 통계 관련 메서드를 별도 파일로 분리한다.
직접 사용하지 말고 SqliteStore를 통해 접근한다.
"""
from __future__ import annotations

import sqlite3

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None


def _row_to_dict(row: sqlite3.Row) -> dict[str, _SqliteVal]:
    """sqlite3.Row 객체를 일반 딕셔너리로 변환한다."""
    return dict(row)


def log_usage(
    conn: sqlite3.Connection,
    run_id: int | None,
    processed_item_id: int | None,
    model_name: str,
    task_type: str,
    latency_ms: int,
    input_tokens: int | None,
    success: int,
) -> int:
    """모델 추론 사용 기록을 삽입하고 삽입된 id를 반환한다."""
    cursor = conn.execute(
        """
        INSERT INTO model_usage_log
            (run_id, processed_item_id, model_name, task_type,
             latency_ms, input_tokens, success)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (run_id, processed_item_id, model_name, task_type,
         latency_ms, input_tokens, success),
    )
    conn.commit()
    row_id = cursor.lastrowid
    if row_id is None:
        raise RuntimeError("INSERT 후 lastrowid가 None — model_usage_log 삽입 실패")
    return row_id


def get_by_date_range(
    conn: sqlite3.Connection, start: str, end: str
) -> list[dict[str, _SqliteVal]]:
    """날짜 범위(YYYY-MM-DD HH:MM:SS) 내 사용 기록을 반환한다."""
    rows = conn.execute(
        "SELECT * FROM model_usage_log WHERE created_at BETWEEN ? AND ? "
        "ORDER BY created_at DESC",
        (start, end),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def get_avg_latency_by_model(
    conn: sqlite3.Connection, days: int = 30
) -> list[dict[str, _SqliteVal]]:
    """최근 N일간 모델별 평균 추론 지연시간을 반환한다 (Flutter 통계 차트용)."""
    rows = conn.execute(
        """
        SELECT model_name, task_type,
               COUNT(*) AS call_count,
               AVG(latency_ms) AS avg_latency_ms,
               SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) AS fail_count
        FROM model_usage_log
        WHERE created_at >= datetime('now', ? || ' days', 'localtime')
        GROUP BY model_name, task_type
        ORDER BY model_name, task_type
        """,
        (f"-{days}",),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]
