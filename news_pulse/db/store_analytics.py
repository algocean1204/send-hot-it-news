"""
분석/통계 쿼리 메서드 모음 (F08 필터 분석, F09 소스 분석 공유).

SqliteStore의 분석 관련 읽기 전용 쿼리를 별도 파일로 분리한다.
직접 사용하지 말고 SqliteStore를 통해 접근한다.
"""
from __future__ import annotations

import sqlite3

# SQLite가 반환할 수 있는 값 타입의 합집합 — Any 사용을 피하기 위한 정밀 타입 별칭
_SqliteVal = str | int | float | None


def _row_to_dict(row: sqlite3.Row) -> dict[str, _SqliteVal]:
    """sqlite3.Row 객체를 일반 딕셔너리로 변환한다."""
    return dict(row)


def get_filtered_word_frequency(
    conn: sqlite3.Connection, days: int = 30, limit: int = 20
) -> list[dict[str, _SqliteVal]]:
    """
    최근 N일간 필터링된 아이템의 제목 단어 빈도를 반환한다.

    필터 통과 실패(telegram_sent=0 AND is_hot=0) 아이템의 제목을 공백 분할하여
    단어별 출현 횟수를 집계한다. Flutter F08 필터 분석 화면에서 사용한다.
    참고: SQLite는 정규식 단어 분리를 지원하지 않아 title 단위 집계를 사용한다.
    """
    rows = conn.execute(
        """
        SELECT title, COUNT(*) AS freq
        FROM processed_items
        WHERE telegram_sent = 0
          AND is_hot = 0
          AND created_at >= datetime('now', ? || ' days', 'localtime')
        GROUP BY title
        ORDER BY freq DESC
        LIMIT ?
        """,
        (f"-{days}", limit),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def get_pass_rate_by_source(
    conn: sqlite3.Connection, days: int = 30
) -> list[dict[str, _SqliteVal]]:
    """
    최근 N일간 소스별 필터 통과율을 반환한다.

    source별 총 건수, 통과 건수(telegram_sent=1 또는 is_hot=1), 통과율을 계산한다.
    Flutter F09 소스 분석 화면에서 사용한다.
    """
    rows = conn.execute(
        """
        SELECT source,
               COUNT(*) AS total,
               SUM(CASE WHEN telegram_sent = 1 OR is_hot = 1 THEN 1 ELSE 0 END) AS passed,
               ROUND(
                   100.0 * SUM(CASE WHEN telegram_sent = 1 OR is_hot = 1 THEN 1 ELSE 0 END)
                   / COUNT(*), 2
               ) AS rate
        FROM processed_items
        WHERE created_at >= datetime('now', ? || ' days', 'localtime')
        GROUP BY source
        ORDER BY total DESC
        """,
        (f"-{days}",),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]


def get_upvote_distribution(
    conn: sqlite3.Connection, source_id: str, days: int = 30
) -> list[dict[str, _SqliteVal]]:
    """
    특정 소스의 업보트 값 분포를 반환한다.

    Flutter F09 소스 분석 화면의 업보트 히스토그램에서 사용한다.
    source_id는 processed_items.source 컬럼값과 동일한 문자열이다.
    """
    rows = conn.execute(
        """
        SELECT upvotes, COUNT(*) AS item_count
        FROM processed_items
        WHERE source = ?
          AND created_at >= datetime('now', ? || ' days', 'localtime')
        GROUP BY upvotes
        ORDER BY upvotes ASC
        """,
        (source_id, f"-{days}"),
    ).fetchall()
    return [_row_to_dict(r) for r in rows]
