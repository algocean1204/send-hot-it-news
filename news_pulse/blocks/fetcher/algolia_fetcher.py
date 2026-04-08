"""
Algolia 검색 API 기반 Hacker News 수집기.

HN Algolia API에서 최신 스토리를 JSON으로 가져온다.
"""
from __future__ import annotations

import hashlib
import logging
from datetime import datetime

import httpx

from news_pulse.models.config import Config
from news_pulse.models.news import RawItem

logger = logging.getLogger(__name__)

# 이 수집기가 담당하는 소스 타입
_SOURCE_TYPE = "algolia"
# Algolia HN 검색 엔드포인트 — HTTPS 사용 (HTTP는 리다이렉트 발생)
# source.url은 algolia 소스 타입 식별에만 사용되고, 실제 API URL은 이 상수로 고정한다
_HN_URL = "https://hn.algolia.com/api/v1/search_by_date"
# 한 번에 가져올 스토리 수
_PAGE_SIZE = 30


class AlgoliaFetcher:
    """Hacker News Algolia API로 최신 스토리를 수집하는 구현체."""

    def fetch(self, config: Config) -> list[RawItem]:
        """HN Algolia API를 호출해 RawItem 목록을 반환한다."""
        sources = [s for s in config.sources if s.source_type == _SOURCE_TYPE and s.enabled]
        if not sources:
            return []
        results: list[RawItem] = []
        for source in sources:
            try:
                results.extend(self._fetch_source(source.source_id))
            except Exception as exc:
                logger.warning("Algolia 소스 '%s' 실패, 건너뜀: %s", source.source_id, exc)
        return results

    def _fetch_source(self, source_id: str) -> list[RawItem]:
        """API를 호출하고 story 타입 아이템만 RawItem으로 변환한다."""
        params = {"tags": "story", "hitsPerPage": _PAGE_SIZE}
        # follow_redirects=True: httpx 기본값은 False여서 HTTP→HTTPS 리다이렉트를 놓친다
        resp = httpx.get(_HN_URL, params=params, timeout=10, follow_redirects=True)
        resp.raise_for_status()
        hits: list[dict[str, object]] = resp.json().get("hits", [])

        items: list[RawItem] = []
        for hit in hits:
            url = str(hit.get("url") or hit.get("story_url") or "")
            if not url:
                continue
            url_hash = hashlib.sha256(url.encode()).hexdigest()
            upvotes = hit.get("points")
            items.append(RawItem(
                url=url,
                title=str(hit.get("title", "")),
                content=str(hit.get("story_text") or ""),
                source_id=source_id,
                fetched_at=datetime.now(),
                upvotes=int(upvotes) if upvotes is not None else None,
                published_at=self._parse_ts(hit.get("created_at")),
                url_hash=url_hash,
            ))
        return items

    def _parse_ts(self, created_at: object) -> datetime | None:
        """ISO8601 문자열을 datetime으로 변환한다."""
        if not created_at:
            return None
        try:
            return datetime.fromisoformat(str(created_at).replace("Z", "+00:00"))
        except ValueError:
            return None
