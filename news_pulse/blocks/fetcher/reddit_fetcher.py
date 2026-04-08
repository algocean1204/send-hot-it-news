"""
Reddit JSON 엔드포인트 수집기.

r/LocalLLaMA, r/ClaudeAI, r/cursor 서브레딧의 hot 게시물을 가져온다.
비인증 접근, 커스텀 User-Agent 필수.
"""
from __future__ import annotations

import hashlib
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import httpx

from news_pulse.models.config import Config, SourceConfig
from news_pulse.models.news import RawItem

logger = logging.getLogger(__name__)

# 이 수집기가 담당하는 소스 타입
_SOURCE_TYPE = "reddit"
# Reddit 비인증 접근에 필요한 커스텀 User-Agent
_USER_AGENT = "news-pulse/1.0 (macOS; automated news aggregator; contact via github)"
# 가져올 게시물 수
_LIMIT = 25
# 병렬 워커 수
_MAX_WORKERS = 3


class RedditFetcher:
    """Reddit .json 엔드포인트로 hot 게시물을 수집하는 구현체."""

    def fetch(self, config: Config) -> list[RawItem]:
        """활성화된 Reddit 소스를 병렬로 수집한다."""
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
                    logger.warning("Reddit 소스 '%s' 실패, 건너뜀: %s", source.source_id, exc)
        return results

    def _fetch_source(self, source: SourceConfig) -> list[RawItem]:
        """단일 서브레딧에서 hot 게시물을 가져온다."""
        # .json 확장자 없으면 붙인다 — Reddit JSON API 규칙
        url = source.url
        if not url.endswith(".json"):
            url = url.rstrip("/") + ".json"

        headers = {"User-Agent": _USER_AGENT}
        params = {"limit": _LIMIT}
        # follow_redirects=True: Reddit은 HTTP→HTTPS 리다이렉트를 사용한다
        resp = httpx.get(url, headers=headers, params=params, timeout=10, follow_redirects=True)
        resp.raise_for_status()
        # JSON 응답은 구조가 정해져 있으므로 list[object]로 선언 후 각 필드를 명시적으로 캐스팅한다
        children: list[object] = resp.json()["data"]["children"]

        items: list[RawItem] = []
        for child in children:
            post = child["data"]
            post_url = post.get("url") or f"https://www.reddit.com{post.get('permalink', '')}"
            if not post_url:
                continue
            url_hash = hashlib.sha256(post_url.encode()).hexdigest()
            created_utc = post.get("created_utc")
            # feedparser/Reddit의 created_utc는 UTC 기준값 — fromtimestamp는 로컬 TZ를 적용하므로 UTC 변환 필수
            published_at = (
                datetime.fromtimestamp(float(created_utc), tz=timezone.utc).replace(tzinfo=None)
                if created_utc else None
            )
            items.append(RawItem(
                url=post_url,
                title=str(post.get("title", "")),
                content=str(post.get("selftext") or ""),
                source_id=source.source_id,
                fetched_at=datetime.now(),
                upvotes=int(post.get("score", 0)),
                published_at=published_at,
                url_hash=url_hash,
            ))
        return items
