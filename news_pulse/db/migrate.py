"""
마이그레이션 실행 스크립트.

schema.sql + seed.sql을 순서대로 실행한다.
IF NOT EXISTS / INSERT OR IGNORE 덕분에 멱등성이 보장된다.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path


# SQL 파일 위치 — migrate.py와 같은 디렉터리에 존재
_DB_DIR = Path(__file__).parent
_SCHEMA_PATH = _DB_DIR / "schema.sql"
_SEED_PATH = _DB_DIR / "seed.sql"

# 정상 마이그레이션 후 존재해야 하는 테이블 수
_EXPECTED_TABLE_COUNT = 11


def _load_sql(path: Path) -> str:
    """SQL 파일을 읽어 문자열로 반환한다."""
    with open(path, encoding="utf-8") as f:
        return f.read()


def _first_word(stmt: str) -> str:
    """주석을 제거한 SQL 구문의 첫 번째 키워드를 반환한다."""
    clean = "\n".join(
        line for line in stmt.splitlines() if not line.strip().startswith("--")
    ).strip()
    parts = clean.split()
    return parts[0].upper() if parts else ""


def _execute_pragmas(conn: sqlite3.Connection, sql: str) -> None:
    """PRAGMA 구문만 먼저 실행한다 (트랜잭션 밖에서 호출해야 함)."""
    for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
        if _first_word(stmt) == "PRAGMA":
            conn.execute(stmt)
    conn.commit()


def _execute_non_pragma(conn: sqlite3.Connection, sql: str) -> None:
    """PRAGMA를 제외한 DDL/DML 구문을 실행한다 (트랜잭션 안에서 호출)."""
    for stmt in [s.strip() for s in sql.split(";") if s.strip()]:
        fw = _first_word(stmt)
        if fw and fw != "PRAGMA":
            conn.execute(stmt)


def _execute_script(conn: sqlite3.Connection, sql: str) -> None:
    """
    세미콜론 구분자로 SQL을 분할하여 순서대로 실행한다.

    executescript()는 PRAGMA를 무시할 수 있어 직접 분할 실행 방식을 사용한다.
    주석(-- ...)과 빈 구문은 건너뛴다.
    commit() 없이 실행만 한다 — 트랜잭션은 호출자(migrate)가 관리한다.
    """
    statements = [s.strip() for s in sql.split(";") if s.strip()]
    for stmt in statements:
        # 주석만 있는 블럭은 실행하지 않는다
        non_comment = "\n".join(
            line for line in stmt.splitlines() if not line.strip().startswith("--")
        ).strip()
        if non_comment:
            conn.execute(stmt)


def _column_exists(conn: sqlite3.Connection, table: str, column: str) -> bool:
    """PRAGMA table_info로 컬럼 존재 여부를 확인한다 (ALTER 멱등성 보장용)."""
    rows = conn.execute(f"PRAGMA table_info({table})").fetchall()
    return any(row[1] == column for row in rows)


def _apply_alter_tables(conn: sqlite3.Connection) -> None:
    """
    processed_items에 신규 컬럼 4개를 추가한다.

    ALTER TABLE은 IF NOT EXISTS를 지원하지 않으므로,
    PRAGMA table_info로 컬럼 존재 여부를 확인 후 조건부 실행한다.
    """
    # (컬럼명, DDL 타입 + 기본값) 순서 유지 — FK는 ALTER로 추가 불가하여 생략
    new_columns: list[tuple[str, str]] = [
        ("is_read", "INTEGER NOT NULL DEFAULT 0"),
        ("summarizer_model", "TEXT"),
        ("translator_model", "TEXT"),
        ("prompt_version_id", "INTEGER"),
    ]
    for col, definition in new_columns:
        if not _column_exists(conn, "processed_items", col):
            conn.execute(
                f"ALTER TABLE processed_items ADD COLUMN {col} {definition}"
            )
    # 읽음 상태 조회 인덱스 — CREATE INDEX IF NOT EXISTS는 멱등 실행 가능
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_processed_is_read "
        "ON processed_items(is_read)"
    )
    conn.commit()


def _verify_tables(conn: sqlite3.Connection) -> None:
    """
    사용자 정의 테이블 수가 기댓값과 일치하는지 검증한다.

    sqlite_sequence는 AUTOINCREMENT 사용 시 SQLite가 자동으로 생성하는
    내부 테이블이므로 카운트에서 제외한다.
    """
    row = conn.execute(
        "SELECT COUNT(*) as cnt FROM sqlite_master "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    ).fetchone()
    actual = row[0]
    if actual != _EXPECTED_TABLE_COUNT:
        raise RuntimeError(
            f"테이블 수 불일치 — 기대: {_EXPECTED_TABLE_COUNT}개, 실제: {actual}개"
        )


def _verify_pragmas(conn: sqlite3.Connection) -> None:
    """WAL 모드와 FK 제약조건이 활성화되어 있는지 확인한다."""
    journal_row = conn.execute("PRAGMA journal_mode").fetchone()
    if journal_row[0].lower() != "wal":
        raise RuntimeError(f"journal_mode가 WAL이 아님: {journal_row[0]}")

    fk_row = conn.execute("PRAGMA foreign_keys").fetchone()
    if fk_row[0] != 1:
        raise RuntimeError("foreign_keys PRAGMA가 비활성화되어 있음")


def migrate(db_path: str) -> None:
    """
    스키마 생성 + 시드 데이터 삽입을 수행한다.

    멱등성 보장: IF NOT EXISTS / INSERT OR IGNORE 사용으로
    동일 DB에 여러 번 실행해도 에러가 발생하지 않는다.

    Args:
        db_path: SQLite DB 파일 경로 (존재하지 않으면 생성된다)
    """
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    schema_sql = _load_sql(_SCHEMA_PATH)
    seed_sql = _load_sql(_SEED_PATH)

    conn = sqlite3.connect(db_path)
    try:
        # PRAGMA는 트랜잭션 밖에서 먼저 실행해야 한다 (WAL 변경 제약)
        _execute_pragmas(conn, schema_sql)
        # DDL(CREATE TABLE/INDEX) + 시드(INSERT OR IGNORE)를 단일 트랜잭션으로 묶는다
        conn.execute("BEGIN")
        _execute_non_pragma(conn, schema_sql)
        _execute_script(conn, seed_sql)
        conn.execute("COMMIT")
        # ALTER TABLE은 트랜잭션 밖에서 별도 실행한다 (SQLite WAL 제약 대응)
        _apply_alter_tables(conn)
        _verify_tables(conn)
        _verify_pragmas(conn)
    except Exception:
        try:
            conn.execute("ROLLBACK")
        except Exception:
            pass
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    import sys

    # python -m news_pulse.db.migrate [db_path] 형태로 직접 실행 가능
    target_path = sys.argv[1] if len(sys.argv) > 1 else "~/.news-pulse/news_pulse.db"
    resolved = str(Path(target_path).expanduser())
    print(f"마이그레이션 시작: {resolved}")
    migrate(resolved)
    print("마이그레이션 완료: 11개 테이블 + ALTER 컬럼 4개 + 시드 데이터 삽입 성공")
