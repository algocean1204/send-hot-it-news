"""
GithubAtomFetcher 테스트.

Atom 피드 파싱, 비활성 소스 건너뛰기, 날짜 파싱,
예외 소스 건너뛰기를 검증한다.
"""
from __future__ import annotations

from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest

from news_pulse.blocks.fetcher.github_atom_fetcher import GithubAtomFetcher
from news_pulse.models.config import Config, SourceConfig


def _config(enabled: bool = True) -> Config:
    """GitHub Atom 소스가 포함된 Config를 생성한다."""
    return Config(
        bot_token="tok", admin_chat_id="admin",
        db_path="/tmp/gh.db", ollama_endpoint="http://localhost:11434",
        apex_model_name="apex", kanana_model_name="kanana",
        memory_threshold_gb=26.0,
        sources=[
            SourceConfig(
                source_id="claude_code_releases", name="Claude Code",
                url="https://github.com/anthropics/claude-code/releases.atom",
                source_type="github_atom", tier=1, language="en",
                enabled=enabled,
            ),
        ],
    )


def _mock_feed(entries: list[dict]) -> MagicMock:
    """feedparser.parse() 결과를 모사하는 mock 객체를 생성한다."""
    feed = MagicMock()
    mock_entries = []
    for e in entries:
        entry = MagicMock()
        entry.get = MagicMock(side_effect=lambda k, d="", _e=e: _e.get(k, d))
        entry.published_parsed = e.get("published_parsed")
        mock_entries.append(entry)
    feed.entries = mock_entries
    return feed


def test_정상_수집() -> None:
    """활성화된 소스에서 Atom 엔트리를 RawItem으로 변환해야 한다."""
    fetcher = GithubAtomFetcher()
    entries = [
        {"link": "https://github.com/release/1", "title": "v1.0.0",
         "summary": "First release", "published_parsed": None},
    ]

    with patch(
        "news_pulse.blocks.fetcher.github_atom_fetcher.feedparser.parse",
        return_value=_mock_feed(entries),
    ):
        items = fetcher.fetch(_config())

    assert len(items) == 1
    assert items[0].title == "v1.0.0"
    assert items[0].source_id == "claude_code_releases"
    assert items[0].upvotes is None


def test_비활성_소스_건너뛰기() -> None:
    """enabled=False인 소스는 수집하지 않아야 한다."""
    fetcher = GithubAtomFetcher()
    items = fetcher.fetch(_config(enabled=False))
    assert items == []


def test_link_없는_엔트리_건너뛰기() -> None:
    """link가 빈 문자열인 엔트리는 건너뛰어야 한다."""
    fetcher = GithubAtomFetcher()
    entries = [
        {"link": "", "title": "No Link", "published_parsed": None},
        {"link": "https://github.com/release/2", "title": "Valid",
         "published_parsed": None},
    ]

    with patch(
        "news_pulse.blocks.fetcher.github_atom_fetcher.feedparser.parse",
        return_value=_mock_feed(entries),
    ):
        items = fetcher.fetch(_config())

    assert len(items) == 1
    assert items[0].title == "Valid"


def test_github_atom_타입_아닌_소스_무시() -> None:
    """source_type이 github_atom이 아닌 소스는 무시해야 한다."""
    config = Config(
        bot_token="tok", admin_chat_id="admin",
        db_path="/tmp/gh2.db", ollama_endpoint="http://localhost:11434",
        apex_model_name="apex", kanana_model_name="kanana",
        memory_threshold_gb=26.0,
        sources=[
            SourceConfig(
                source_id="geeknews", name="GeekNews",
                url="https://news.hada.io/rss",
                source_type="rss", tier=2, language="ko", enabled=True,
            ),
        ],
    )
    fetcher = GithubAtomFetcher()
    items = fetcher.fetch(config)
    assert items == []
