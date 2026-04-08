"""
GitHub Releases Atom 피드 수집기.

Claude Code Releases, Cline Releases 소스를 처리한다.
feedparser로 Atom 피드를 파싱한다.
"""
from __future__ import annotations

import calendar
import hashlib
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

import feedparser
import httpx

from news_pulse.models.config import Config, SourceConfig
from news_pulse.models.news import RawItem

logger = logging.getLogger(__name__)

# 이 수집기가 담당하는 소스 타입
_SOURCE_TYPE = "github_atom"
_MAX_WORKERS = 2


class GithubAtomFetcher:
    """GitHub Releases Atom 피드를 feedparser로 수집하는 구현체."""

    def fetch(self, config: Config) -> list[RawItem]:
        """활성화된 GitHub Atom 소스를 병렬로 수집한다."""
        sources = [s for s in config.sources if s.source_type == _SOURCE_TYPE and s.enabled]
        if not sources:
            return []
        results: list[RawItem] = []
        with ThreadPoolExecutor(max_workers=_MAX_WORKERS) as executor:
            futures = {executor.submit(self._fetch_source, s): s for s in sources}
            for future in as_completed(futures):
                source = futures[future]
                try:
                    results.extend(future.result())
                except Exception as exc:
                    logger.warning("GitHub Atom 소스 '%s' 실패, 건너뜀: %s", source.source_id, exc)
        return results

    def _fetch_source(self, source: SourceConfig) -> list[RawItem]:
        """단일 GitHub Atom 피드를 파싱해 RawItem 목록을 반환한다."""
        # feedparser에 직접 URL을 전달하면 타임아웃이 없다.
        # httpx로 선행 취득 후 바이트를 feedparser에 전달해 타임아웃을 보장한다.
        resp = httpx.get(source.url, timeout=10, follow_redirects=True)
        resp.raise_for_status()
        feed = feedparser.parse(resp.text)
        items: list[RawItem] = []
        for entry in feed.entries:
            url = entry.get("link", "")
            if not url:
                continue
            url_hash = hashlib.sha256(url.encode()).hexdigest()
            published_at = self._parse_date(entry)
            items.append(RawItem(
                url=url,
                title=entry.get("title", ""),
                content=entry.get("summary") or entry.get("content", [{}])[0].get("value"),
                source_id=source.source_id,
                fetched_at=datetime.now(),
                upvotes=None,
                published_at=published_at,
                url_hash=url_hash,
            ))
        return items

    def _parse_date(self, entry: object) -> datetime | None:
        """Atom 엔트리에서 published 날짜를 UTC 기준으로 파싱한다."""
        published_parsed = getattr(entry, "published_parsed", None)
        if published_parsed:
            try:
                # feedparser는 published_parsed를 UTC time.struct_time으로 반환한다.
                # mktime()은 로컬 TZ로 해석하므로 +9h 오프셋이 생긴다.
                # calendar.timegm()은 UTC로 해석해 올바른 timestamp를 반환한다.
                ts = calendar.timegm(published_parsed)
                return datetime.utcfromtimestamp(ts)
            except (OSError, OverflowError):
                pass
        return None
