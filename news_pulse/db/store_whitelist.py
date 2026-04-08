"""
whitelist_keywords 테이블 접근 메서드 모음.

SqliteStore의 화이트리스트 키워드 관련 메서드를 별도 파일로 분리한다.
직접 사용하지 말고 SqliteStore를 통해 접근한다.
"""
from __future__ import annotations

import sqlite3

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None


def _row_to_dict(row: sqlite3.Row) -> dict[str, _SqliteVal]:
    """sqlite3.Row 객체를 일반 딕셔너리로 변환한다."""
    return dict(row)


def get_all(conn: sqlite3.Connection) -> list[dict[str, _SqliteVal]]:
    """전체 화이트리스트 키워드 목록을 반환한다 (Flutter 설정 화면용)."""
    rows = conn.execute(
        "SELECT * FROM whitelist_keywords ORDER BY created_at DESC"
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def add(conn: sqlite3.Connection, keyword: str) -> int:
    """키워드를 추가한다. 소문자로 정규화 후 저장하며 삽입된 id를 반환한다."""
    cursor = conn.execute(
        "INSERT INTO whitelist_keywords (keyword) VALUES (?)",
        (keyword.lower(),),
    )
    conn.commit()
    row_id = cursor.lastrowid
    if row_id is None:
        raise RuntimeError("INSERT 후 lastrowid가 None — whitelist_keywords 삽입 실패")
    return row_id


def delete(conn: sqlite3.Connection, keyword_id: int) -> None:
    """지정 id의 키워드를 삭제한다."""
    conn.execute("DELETE FROM whitelist_keywords WHERE id = ?", (keyword_id,))
    conn.commit()


def get_keywords_set(conn: sqlite3.Connection) -> set[str]:
    """
    파이프라인 필터링용 키워드 집합을 반환한다.

    TierRouter가 Tier3 아이템 매칭 시 매 실행마다 한 번 호출하며,
    set 자료구조로 반환해 O(1) 조회를 가능하게 한다.
    """
    rows = conn.execute("SELECT keyword FROM whitelist_keywords").fetchall()
    return {r["keyword"] for r in rows}
