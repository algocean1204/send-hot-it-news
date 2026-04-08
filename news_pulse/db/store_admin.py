"""
관리 테이블(run_history, error_log, filter_config, health_check_results) 접근 메서드.

SqliteStore의 관리 관련 메서드를 별도 파일로 분리한다.
직접 사용하지 말고 SqliteStore를 통해 접근한다.
"""
from __future__ import annotations

import sqlite3

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None

# run_history 업데이트 허용 컬럼 화이트리스트 (SQL 인젝션 방지)
_RUN_HISTORY_COLUMNS = frozenset({
    "finished_at", "status", "fetched_count", "filtered_count",
    "summarized_count", "sent_count", "total_duration_ms",
    "model_load_ms", "inference_ms", "memory_mode", "error_message",
})


def _row_to_dict(row: sqlite3.Row) -> dict[str, _SqliteVal]:
    """sqlite3.Row 객체를 일반 딕셔너리로 변환한다."""
    return dict(row)


def insert_run(conn: sqlite3.Connection, run: dict[str, _SqliteVal]) -> int:
    """실행 기록 삽입. 삽입된 row id를 반환한다."""
    cursor = conn.execute(
        """
        INSERT INTO run_history (started_at, status, memory_mode)
        VALUES (:started_at, :status, :memory_mode)
        """,
        run,
    )
    conn.commit()
    row_id = cursor.lastrowid
    if row_id is None:
        raise RuntimeError("INSERT 후 lastrowid가 None — run_history 삽입 실패")
    return row_id


def update_run(
    conn: sqlite3.Connection, run_id: int, updates: dict[str, _SqliteVal]
) -> None:
    """실행 기록 업데이트 (컬럼명 화이트리스트 검증 포함)."""
    if not updates:
        return
    # 허용되지 않은 컬럼명이 있으면 즉시 거부
    invalid = set(updates.keys()) - _RUN_HISTORY_COLUMNS
    if invalid:
        raise ValueError(f"허용되지 않은 컬럼: {invalid}")
    set_clause = ", ".join(f"{k} = :{k}" for k in updates)
    updates["_id"] = run_id
    conn.execute(
        f"UPDATE run_history SET {set_clause} WHERE id = :_id", updates
    )
    conn.commit()


def get_latest_run(conn: sqlite3.Connection) -> dict[str, _SqliteVal] | None:
    """가장 최근 실행 기록 반환."""
    row = conn.execute(
        "SELECT * FROM run_history ORDER BY started_at DESC LIMIT 1"
    ).fetchone()
    return _row_to_dict(row) if row else None


def get_run_history(
    conn: sqlite3.Connection, limit: int = 50
) -> list[dict[str, _SqliteVal]]:
    """실행 이력 목록 (최신순 내림차순, Flutter 화면 4용)."""
    rows = conn.execute(
        "SELECT * FROM run_history ORDER BY started_at DESC LIMIT ?", (limit,)
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def insert_error(conn: sqlite3.Connection, error: dict[str, _SqliteVal]) -> None:
    """에러 로그 삽입 (run_id는 nullable)."""
    conn.execute(
        """
        INSERT INTO error_log (run_id, severity, module, message, traceback)
        VALUES (:run_id, :severity, :module, :message, :traceback)
        """,
        error,
    )
    conn.commit()


def get_recent_errors(
    conn: sqlite3.Connection, limit: int = 10
) -> list[dict[str, _SqliteVal]]:
    """최근 에러 목록 조회 (Flutter 화면 5용)."""
    rows = conn.execute(
        "SELECT * FROM error_log ORDER BY created_at DESC LIMIT ?", (limit,)
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def get_errors_by_severity(
    conn: sqlite3.Connection, severity: str
) -> list[dict[str, _SqliteVal]]:
    """심각도별 에러 조회."""
    rows = conn.execute(
        "SELECT * FROM error_log WHERE severity = ? ORDER BY created_at DESC",
        (severity,),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def get_config_value(conn: sqlite3.Connection, key: str) -> str | None:
    """설정 값 조회. 없으면 None 반환."""
    row = conn.execute(
        "SELECT value FROM filter_config WHERE key = ?", (key,)
    ).fetchone()
    return row["value"] if row else None


def set_config_value(conn: sqlite3.Connection, key: str, value: str) -> None:
    """설정 값 저장. INSERT OR REPLACE로 중복 키 처리."""
    conn.execute(
        """
        INSERT INTO filter_config (key, value, updated_at)
        VALUES (?, ?, datetime('now','localtime'))
        ON CONFLICT(key) DO UPDATE SET
            value      = excluded.value,
            updated_at = excluded.updated_at
        """,
        (key, value),
    )
    conn.commit()


def get_all_config(conn: sqlite3.Connection) -> dict[str, str]:
    """전체 설정 조회 (key -> value 딕셔너리, Flutter 화면 7용)."""
    rows = conn.execute("SELECT key, value FROM filter_config").fetchall()
    return {r["key"]: r["value"] for r in rows}


def insert_health_check(
    conn: sqlite3.Connection, check: dict[str, _SqliteVal]
) -> None:
    """헬스체크 결과 삽입 (HealthChecker가 호출)."""
    conn.execute(
        """
        INSERT INTO health_check_results
            (check_type, target, status, message, response_time_ms)
        VALUES
            (:check_type, :target, :status, :message, :response_time_ms)
        """,
        check,
    )
    conn.commit()


def get_latest_health_checks(
    conn: sqlite3.Connection,
) -> list[dict[str, _SqliteVal]]:
    """
    가장 최근 헬스체크 세트 조회.

    check_type + target 조합별 최신 결과(id 기준 최대값)만 반환한다.
    """
    rows = conn.execute(
        """
        SELECT hcr.*
        FROM health_check_results hcr
        INNER JOIN (
            SELECT check_type, target, MAX(id) AS max_id
            FROM health_check_results
            GROUP BY check_type, target
        ) latest
        ON hcr.id = latest.max_id
        ORDER BY hcr.check_type, hcr.target
        """
    ).fetchall()
    return [_row_to_dict(r) for r in rows]
