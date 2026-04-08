"""
RSS/Atom 피드 수집기.

GeekNews, Anthropic, OpenAI, DeepMind, HuggingFace, Cursor Changelog 소스를 처리한다.
feedparser로 파싱하며, 소스별 독립 실행으로 개별 실패를 허용한다.
"""
from __future__ import annotations

import hashlib
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from email.utils import parsedate_to_datetime

import feedparser
import httpx

from news_pulse.models.config import Config, SourceConfig
from news_pulse.models.news import RawItem

logger = logging.getLogger(__name__)

# 이 수집기가 담당하는 소스 타입
_SOURCE_TYPE = "rss"
# 병렬 수집 최대 워커 수
_MAX_WORKERS = 6


class RssFetcher:
    """RSS/Atom 피드를 feedparser로 파싱하는 수집기."""

    def fetch(self, config: Config) -> list[RawItem]:
        """활성화된 RSS 소스를 병렬로 수집해 RawItem 목록을 반환한다."""
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
                    logger.warning("RSS 소스 '%s' 실패, 건너뜀: %s", source.source_id, exc)
        return results

    def _fetch_source(self, source: SourceConfig) -> list[RawItem]:
        """단일 RSS 소스를 파싱해 RawItem 목록을 반환한다."""
        # feedparser.parse(url)은 타임아웃이 없다.
        # httpx로 선행 취득 후 텍스트를 feedparser에 전달해 타임아웃을 보장한다.
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
                content=entry.get("summary") or entry.get("description"),
                source_id=source.source_id,
                fetched_at=datetime.now(),
                upvotes=None,
                published_at=published_at,
                url_hash=url_hash,
            ))
        return items

    def _parse_date(self, entry: object) -> datetime | None:
        """RSS 엔트리에서 published 날짜를 파싱한다."""
        raw = getattr(entry, "published", None) or getattr(entry, "updated", None)
        if not raw:
            return None
        try:
            return parsedate_to_datetime(raw)
        except Exception as exc:
            logger.warning("RSS 날짜 파싱 실패 ('%s'): %s", raw, exc)
            return None
