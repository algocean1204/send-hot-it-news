"""수집 파이프라인 원자 모듈. 수집기를 병렬 실행해 RawItem 목록과 실패 횟수를 반환한다."""
from __future__ import annotations
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Protocol
from news_pulse.models.config import Config
from news_pulse.models.news import RawItem
logger = logging.getLogger(__name__)
_MAX_FETCH_WORKERS = 4  # 병렬 수집 최대 워커 수


class FetcherProtocol(Protocol):
    """수집기 인터페이스 — fetch 메서드를 가진 객체임을 보증한다."""
    def fetch(self, config: Config) -> list[RawItem]: ...


def fetch_all(fetchers: list[FetcherProtocol], config: Config) -> tuple[list[RawItem], int]:
    """
    수집기 목록을 병렬 실행해 (전체 RawItem 목록, 실패 횟수)를 반환한다.

    개별 수집기 예외 시 경고 로그 후 건너뛰고 fail_count를 증가시킨다.
    """
    results: list[RawItem] = []
    fail_count = 0
    with ThreadPoolExecutor(max_workers=_MAX_FETCH_WORKERS) as executor:
        futures = {executor.submit(f.fetch, config): f for f in fetchers}
        for future in as_completed(futures):
            try:
                results.extend(future.result())
            except Exception as exc:
                logger.warning("수집기 실패, 건너뜀: %s", exc)
                fail_count += 1
    return results, fail_count
