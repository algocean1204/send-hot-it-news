"""
블럭 17 — HealthChecker.

Ollama, 소스 URL, Telegram API, SQLite를 점검하고
HealthReport를 생성한다. 개별 항목 실패는 기록 후 계속 진행한다.
"""
from __future__ import annotations

import logging
import time
from datetime import datetime
from typing import Protocol

import httpx

from news_pulse.db.store import SqliteStore

logger = logging.getLogger(__name__)
from news_pulse.models.config import Config
from news_pulse.models.health import HealthReport, HealthStatus


class HealthCheckerProtocol(Protocol):
    """HealthChecker 인터페이스 정의."""

    def check(self, config: Config) -> HealthReport: ...


class SystemHealthChecker:
    """전체 시스템 헬스체크를 수행하는 구현체."""

    def __init__(self, db: SqliteStore) -> None:
        """db: health_check_results INSERT용 SqliteStore."""
        self._db = db

    def check(self, config: Config) -> HealthReport:
        """Ollama, 소스 URL, Telegram API, SQLite를 점검한다."""
        items: list[HealthStatus] = []
        items.extend(self._check_ollama(config))
        items.extend(self._check_sources(config))
        items.append(self._check_telegram(config))
        items.append(self._check_sqlite(config))

        overall = self._compute_overall(items)
        self._save_to_db(items)
        return HealthReport(checked_at=datetime.now(), overall=overall, items=items)

    def _check_ollama(self, config: Config) -> list[HealthStatus]:
        """Ollama REST API 연결 + APEX/Kanana 모델 등록 여부를 확인한다."""
        results: list[HealthStatus] = []
        try:
            resp = httpx.get(f"{config.ollama_endpoint}/api/tags", timeout=5)
            resp.raise_for_status()
            models = {m["name"] for m in resp.json().get("models", [])}
            results.append(HealthStatus(name="ollama", status="OK", message="연결 정상"))
            for model in [config.apex_model_name, config.kanana_model_name]:
                status = "OK" if any(model in m for m in models) else "WARN"
                msg = "등록됨" if status == "OK" else "미등록 (풀 필요)"
                results.append(HealthStatus(name=f"model:{model}", status=status, message=msg))
        except Exception as exc:
            results.append(HealthStatus(name="ollama", status="ERROR", message=str(exc)))
        return results

    def _check_source_url(self, url: str) -> tuple[int, int]:
        """URL에 HEAD를 시도하고 405 시 GET으로 폴백한다. (status_code, elapsed_ms) 반환."""
        start = time.monotonic()
        resp = httpx.head(url, timeout=5, follow_redirects=True)
        if resp.status_code == 405:
            # Reddit, Algolia 등 HEAD를 허용하지 않는 서버 — GET으로 재시도
            resp = httpx.get(url, timeout=5, follow_redirects=True)
        elapsed_ms = int((time.monotonic() - start) * 1000)
        return resp.status_code, elapsed_ms

    def _check_sources(self, config: Config) -> list[HealthStatus]:
        """12개 소스 URL의 HTTP 응답을 확인한다."""
        results: list[HealthStatus] = []
        for source in config.sources:
            try:
                status_code, elapsed_ms = self._check_source_url(source.url)
                status = "OK" if status_code < 400 else "WARN"
                msg = f"HTTP {status_code} ({elapsed_ms}ms)"
            except Exception as exc:
                status = "ERROR"
                msg = str(exc)
            results.append(HealthStatus(name=f"source:{source.source_id}", status=status, message=msg))
        return results

    def _check_telegram(self, config: Config) -> HealthStatus:
        """Telegram Bot API getMe를 호출해 봇 상태를 확인한다."""
        try:
            url = f"https://api.telegram.org/bot{config.bot_token}/getMe"
            resp = httpx.get(url, timeout=5)
            resp.raise_for_status()
            # HTTP 200이어도 ok:false면 토큰 오류 등 API 레벨 실패
            data = resp.json()
            if not data.get("ok"):
                raise RuntimeError(f"Telegram API 오류: {data.get('description', '알 수 없음')}")
            return HealthStatus(name="telegram", status="OK", message="봇 정상")
        except Exception as exc:
            return HealthStatus(name="telegram", status="ERROR", message=str(exc))

    def _check_sqlite(self, config: Config) -> HealthStatus:
        """SQLite 무결성 검사. SqliteStore의 공개 메서드를 통해 접근한다."""
        try:
            # _conn 직접 접근 금지 — integrity_check() 공개 메서드 사용
            result = self._db.integrity_check()
            ok = result == "ok"
            msg = "무결성 OK" if ok else f"무결성 오류: {result}"
            status = "OK" if ok else "ERROR"
            return HealthStatus(name="sqlite", status=status, message=msg)
        except Exception as exc:
            return HealthStatus(name="sqlite", status="ERROR", message=str(exc))

    def _compute_overall(self, items: list[HealthStatus]) -> str:
        """개별 상태 중 최악의 값을 전체 상태로 반환한다."""
        if any(i.status == "ERROR" for i in items):
            return "ERROR"
        if any(i.status == "WARN" for i in items):
            return "WARN"
        return "OK"

    def _save_to_db(self, items: list[HealthStatus]) -> None:
        """헬스체크 결과를 health_check_results 테이블에 저장한다.
        스키마는 소문자(ok/warning/error)를 기대하므로 소문자로 변환한다."""
        # HealthStatus 내부 비교는 대문자로, DB 저장은 소문자로 통일
        _status_map = {"OK": "ok", "WARN": "warning", "ERROR": "error"}
        for item in items:
            try:
                self._db.insert_health_check({
                    "check_type": item.name.split(":")[0],
                    "target": item.name,
                    "status": _status_map.get(item.status, item.status.lower()),
                    "message": item.message,
                    "response_time_ms": None,
                })
            except Exception as exc:
                logger.warning("헬스체크 결과 DB 저장 실패: %s", exc)
