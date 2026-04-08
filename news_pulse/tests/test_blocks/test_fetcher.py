"""
Fetcher 단위 테스트.

각 수집기가 mock 응답에서 RawItem을 정확히 생성하는지 검증한다.
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

from news_pulse.blocks.fetcher.algolia_fetcher import AlgoliaFetcher
from news_pulse.blocks.fetcher.reddit_fetcher import RedditFetcher
from news_pulse.blocks.fetcher.rss_fetcher import RssFetcher
from news_pulse.models.config import Config, SourceConfig


def _make_config(source_type: str, source_id: str, url: str) -> Config:
    """테스트용 Config를 생성한다."""
    source = SourceConfig(
        source_id=source_id,
        name="Test",
        url=url,
        source_type=source_type,
        tier=1,
        language="en",
        enabled=True,
    )
    return Config(
        bot_token="tok",
        admin_chat_id="1",
        db_path="/tmp/test.db",
        ollama_endpoint="http://localhost:11434",
        apex_model_name="apex",
        kanana_model_name="kanana",
        memory_threshold_gb=26.0,
        sources=[source],
    )


def test_rss_fetcher_returns_items() -> None:
    """RssFetcher가 피드 엔트리를 RawItem으로 변환해야 한다."""
    config = _make_config("rss", "test_rss", "http://example.com/rss")
    mock_feed = MagicMock()
    mock_entry = MagicMock()
    mock_entry.get.side_effect = lambda k, default="": {
        "link": "http://example.com/news/1",
        "title": "테스트 뉴스",
        "summary": "요약 내용",
    }.get(k, default)
    mock_feed.entries = [mock_entry]

    # httpx.get → feedparser.parse(resp.text) 순서로 호출되므로 두 곳을 모두 패치해야 한다
    mock_resp = MagicMock()
    mock_resp.text = "<rss/>"
    mock_resp.raise_for_status = MagicMock()

    with patch("news_pulse.blocks.fetcher.rss_fetcher.httpx.get", return_value=mock_resp), \
         patch("news_pulse.blocks.fetcher.rss_fetcher.feedparser.parse", return_value=mock_feed):
        fetcher = RssFetcher()
        items = fetcher.fetch(config)

    assert len(items) == 1
    assert items[0].source_id == "test_rss"
    assert items[0].url == "http://example.com/news/1"
    assert items[0].url_hash != ""


def test_fetcher_skips_disabled_sources() -> None:
    """비활성화된 소스는 건너뛰어야 한다."""
    source = SourceConfig(
        source_id="disabled",
        name="Disabled",
        url="http://example.com/rss",
        source_type="rss",
        tier=1,
        language="en",
        enabled=False,
    )
    config = Config(
        bot_token="tok",
        admin_chat_id="1",
        db_path="/tmp/test.db",
        ollama_endpoint="http://localhost:11434",
        apex_model_name="apex",
        kanana_model_name="kanana",
        memory_threshold_gb=26.0,
        sources=[source],
    )
    fetcher = RssFetcher()
    items = fetcher.fetch(config)
    assert items == []


def test_algolia_fetcher_returns_items() -> None:
    """AlgoliaFetcher가 API 응답을 RawItem으로 변환해야 한다."""
    config = _make_config("algolia", "hackernews", "http://hn.algolia.com/api/v1/search")
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "hits": [
            {
                "url": "http://news.com/1",
                "title": "HN 뉴스",
                "points": 150,
                "created_at": "2024-01-01T00:00:00Z",
                "story_text": None,
            }
        ]
    }
    mock_resp.raise_for_status = MagicMock()

    with patch("news_pulse.blocks.fetcher.algolia_fetcher.httpx.get", return_value=mock_resp):
        fetcher = AlgoliaFetcher()
        items = fetcher.fetch(config)

    assert len(items) == 1
    assert items[0].upvotes == 150
    assert items[0].source_id == "hackernews"


def test_reddit_fetcher_returns_items() -> None:
    """RedditFetcher가 JSON 응답을 RawItem으로 변환해야 한다."""
    config = _make_config(
        "reddit", "reddit_localllama", "https://www.reddit.com/r/LocalLLaMA/hot.json"
    )
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "data": {
            "children": [
                {
                    "data": {
                        "url": "http://reddit.com/r/test/1",
                        "title": "Reddit 게시물",
                        "score": 200,
                        "selftext": "내용",
                        "created_utc": 1700000000,
                        "permalink": "/r/test/1",
                    }
                }
            ]
        }
    }
    mock_resp.raise_for_status = MagicMock()

    with patch("news_pulse.blocks.fetcher.reddit_fetcher.httpx.get", return_value=mock_resp):
        fetcher = RedditFetcher()
        items = fetcher.fetch(config)

    assert len(items) == 1
    assert items[0].upvotes == 200
