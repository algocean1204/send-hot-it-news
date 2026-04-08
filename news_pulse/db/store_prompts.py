"""
prompt_versions 테이블 접근 메서드 모음.

SqliteStore의 프롬프트 버전 관리 관련 메서드를 별도 파일로 분리한다.
직접 사용하지 말고 SqliteStore를 통해 접근한다.
"""
from __future__ import annotations

import sqlite3

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None


def _row_to_dict(row: sqlite3.Row) -> dict[str, _SqliteVal]:
    """sqlite3.Row 객체를 일반 딕셔너리로 변환한다."""
    return dict(row)


def get_active(
    conn: sqlite3.Connection, prompt_type: str
) -> dict[str, _SqliteVal] | None:
    """지정 타입의 현재 활성 프롬프트를 반환한다. 없으면 None."""
    row = conn.execute(
        "SELECT * FROM prompt_versions WHERE prompt_type = ? AND is_active = 1",
        (prompt_type,),
    ).fetchone()
    return _row_to_dict(row) if row else None


def create_version(conn: sqlite3.Connection, prompt_type: str, content: str) -> int:
    """
    새 프롬프트 버전을 생성하고 활성 버전으로 교체한다.

    기존 활성 버전은 is_active=0으로 비활성화하고,
    version 번호는 해당 타입의 최댓값 + 1로 자동 증가한다.
    삽입된 버전 id를 반환한다.
    """
    # 같은 타입의 최신 버전 번호를 조회해 +1 계산
    row = conn.execute(
        "SELECT COALESCE(MAX(version), 0) AS max_ver FROM prompt_versions "
        "WHERE prompt_type = ?",
        (prompt_type,),
    ).fetchone()
    next_version: int = (row["max_ver"] if row else 0) + 1
    # 기존 활성 버전 비활성화 후 신규 버전 삽입 — 원자성 보장
    conn.execute("BEGIN")
    try:
        conn.execute(
            "UPDATE prompt_versions SET is_active = 0 WHERE prompt_type = ? AND is_active = 1",
            (prompt_type,),
        )
        cursor = conn.execute(
            "INSERT INTO prompt_versions (prompt_type, version, content, is_active) "
            "VALUES (?, ?, ?, 1)",
            (prompt_type, next_version, content),
        )
        conn.execute("COMMIT")
    except Exception:
        conn.execute("ROLLBACK")
        raise
    row_id = cursor.lastrowid
    if row_id is None:
        raise RuntimeError("INSERT 후 lastrowid가 None — prompt_versions 삽입 실패")
    return row_id


def get_all(
    conn: sqlite3.Connection, prompt_type: str
) -> list[dict[str, _SqliteVal]]:
    """지정 타입의 전체 버전 목록을 최신순으로 반환한다."""
    rows = conn.execute(
        "SELECT * FROM prompt_versions WHERE prompt_type = ? ORDER BY version DESC",
        (prompt_type,),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def activate(conn: sqlite3.Connection, version_id: int) -> None:
    """
    지정 id의 버전을 활성 버전으로 교체한다.

    같은 prompt_type 내 기존 활성 버전을 먼저 비활성화한 후 지정 버전을 활성화한다.
    """
    row = conn.execute(
        "SELECT prompt_type FROM prompt_versions WHERE id = ?", (version_id,)
    ).fetchone()
    if row is None:
        raise ValueError(f"존재하지 않는 프롬프트 버전 id: {version_id}")
    prompt_type: str = row["prompt_type"]
    conn.execute("BEGIN")
    try:
        conn.execute(
            "UPDATE prompt_versions SET is_active = 0 WHERE prompt_type = ? AND is_active = 1",
            (prompt_type,),
        )
        conn.execute(
            "UPDATE prompt_versions SET is_active = 1 WHERE id = ?", (version_id,)
        )
        conn.execute("COMMIT")
    except Exception:
        conn.execute("ROLLBACK")
        raise
