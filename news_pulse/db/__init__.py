"""
DB 접근 레이어 패키지.

SqliteStore: 모든 블럭이 DB에 접근할 때 사용하는 유틸리티 클래스.
migrate: 스키마 생성 + 시드 데이터 삽입 함수.
"""
from __future__ import annotations

from news_pulse.db.migrate import migrate
from news_pulse.db.store import SqliteStore

__all__ = ["SqliteStore", "migrate"]
