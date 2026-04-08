"""
데이터 정리 및 통계 메서드 모음.

SqliteStore의 cleanup_old_data + 통계 메서드를 별도 파일로 분리한다.
직접 사용하지 말고 SqliteStore를 통해 접근한다.
"""
from __future__ import annotations

import sqlite3

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None


def _row_to_dict(row: sqlite3.Row) -> dict[str, _SqliteVal]:
    """sqlite3.Row 객체를 일반 딕셔너리로 변환한다."""
    return dict(row)


def cleanup_old_data(
    conn: sqlite3.Connection, retention_days: dict[str, int]
) -> dict[str, int]:
    """
    보관 기간이 지난 데이터를 단일 트랜잭션으로 삭제한다.

    6개 DELETE를 하나의 트랜잭션으로 묶어 원자성을 보장한다.
    retention_days 키: processed_items, run_history, error_log, health_check_results,
                      model_usage_log(90일), schedule_log(30일)
    반환: 테이블별 삭제 건수 딕셔너리
    """
    queries: dict[str, tuple[str, str]] = {
        "processed_items": (
            "DELETE FROM processed_items WHERE created_at < "
            "datetime('now', ? || ' days', 'localtime')",
            f"-{retention_days.get('processed_items', 30)}",
        ),
        "run_history": (
            "DELETE FROM run_history WHERE started_at < "
            "datetime('now', ? || ' days', 'localtime')",
            f"-{retention_days.get('run_history', 90)}",
        ),
        "error_log": (
            "DELETE FROM error_log WHERE created_at < "
            "datetime('now', ? || ' days', 'localtime')",
            f"-{retention_days.get('error_log', 30)}",
        ),
        "health_check_results": (
            "DELETE FROM health_check_results WHERE created_at < "
            "datetime('now', ? || ' days', 'localtime')",
            f"-{retention_days.get('health_check_results', 7)}",
        ),
        # model_usage_log: 90일 보관 — 지연 추이 분석 기간과 동일하게 맞춤
        "model_usage_log": (
            "DELETE FROM model_usage_log WHERE created_at < "
            "datetime('now', ? || ' days', 'localtime')",
            f"-{retention_days.get('model_usage_log', 90)}",
        ),
        # schedule_log: 30일 보관 — 단기 스케줄 놓침 감지 목적
        "schedule_log": (
            "DELETE FROM schedule_log WHERE created_at < "
            "datetime('now', ? || ' days', 'localtime')",
            f"-{retention_days.get('schedule_log', 30)}",
        ),
    }
    deleted: dict[str, int] = {}
    # 명시적 트랜잭션으로 4개 DELETE를 원자적으로 실행한다
    conn.execute("BEGIN")
    try:
        for table, (sql, param) in queries.items():
            cursor = conn.execute(sql, (param,))
            deleted[table] = cursor.rowcount
        conn.execute("COMMIT")
    except Exception:
        conn.execute("ROLLBACK")
        raise
    return deleted


def integrity_check(conn: sqlite3.Connection) -> str:
    """PRAGMA integrity_check 결과를 반환한다 (health_checker용 공개 메서드)."""
    row = conn.execute("PRAGMA integrity_check").fetchone()
    return str(row[0]) if row else "unknown"


def vacuum(conn: sqlite3.Connection) -> None:
    """VACUUM을 실행해 DB 파일 크기를 줄인다 (주 1회 호출 권장)."""
    conn.execute("VACUUM")


def get_source_stats(
    conn: sqlite3.Connection, days: int = 7
) -> list[dict[str, _SqliteVal]]:
    """소스별 수집 통계 (최근 N일, Flutter 화면 6 통계 대시보드용)."""
    rows = conn.execute(
        """
        SELECT source,
               COUNT(*) AS total_count,
               SUM(telegram_sent) AS sent_count,
               SUM(is_hot) AS hot_count,
               AVG(upvotes) AS avg_upvotes
        FROM processed_items
        WHERE created_at >= datetime('now', ? || ' days', 'localtime')
        GROUP BY source
        ORDER BY total_count DESC
        """,
        (f"-{days}",),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def get_pipeline_stats(
    conn: sqlite3.Connection, days: int = 7
) -> list[dict[str, _SqliteVal]]:
    """파이프라인 경로별 성공률 통계 (최근 N일, Flutter 화면 6용)."""
    rows = conn.execute(
        """
        SELECT pipeline_path,
               COUNT(*) AS total_count,
               SUM(CASE WHEN summary_ko IS NOT NULL THEN 1 ELSE 0 END) AS success_count,
               AVG(processing_time_ms) AS avg_processing_ms
        FROM processed_items
        WHERE created_at >= datetime('now', ? || ' days', 'localtime')
        GROUP BY pipeline_path
        ORDER BY total_count DESC
        """,
        (f"-{days}",),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]
