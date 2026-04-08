"""
헬스체크 관련 dataclass 모듈.

HealthChecker가 각 컴포넌트(ollama, 소스, telegram, db, disk)를
점검한 결과를 HealthStatus로 표현하고, 전체를 HealthReport로 묶는다.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class HealthStatus:
    """개별 컴포넌트 헬스체크 결과."""

    name: str           # 체크 대상 이름 (예: "ollama", "geeknews")
    status: str         # "OK" | "WARN" | "ERROR"
    message: str        # 상태 메시지


@dataclass
class HealthReport:
    """전체 시스템 헬스체크 리포트. HealthChecker가 생성한다."""

    checked_at: datetime
    overall: str                    # "OK" | "WARN" | "ERROR" (최악 상태 반영)
    items: list[HealthStatus] = field(default_factory=list)  # 개별 체크 결과 목록
