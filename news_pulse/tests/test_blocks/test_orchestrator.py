"""
Orchestrator 통합 테스트.

모든 블럭을 mock으로 대체해 파이프라인 흐름을 검증한다.
"""
from __future__ import annotations

import hashlib
from datetime import datetime
from unittest.mock import MagicMock, patch

from news_pulse.models.config import Config, SourceConfig
from news_pulse.models.news import NewsItem, RawItem, SummaryResult
from news_pulse.models.pipeline import PipelineResult
from news_pulse.models.telegram import SendResult


def _make_config() -> Config:
    source = SourceConfig(
        source_id="hackernews", name="HN", url="http://hn.algolia.com/api/v1/search",
        source_type="algolia", tier=3, language="en", enabled=True,
    )
    return Config(
        bot_token="tok", admin_chat_id="admin1", db_path="/tmp/orch_test.db",
        ollama_endpoint="http://localhost:11434", apex_model_name="apex",
        kanana_model_name="kanana", memory_threshold_gb=26.0, sources=[source],
    )


def _make_raw_item(url: str = "http://news.com/1") -> RawItem:
    return RawItem(
        url=url, title="테스트 뉴스", content="내용", source_id="hackernews",
        fetched_at=datetime.now(), upvotes=100, published_at=None,
        url_hash=hashlib.sha256(url.encode()).hexdigest(),
    )


def _make_news_item(url: str = "http://news.com/1") -> NewsItem:
    return NewsItem(
        url=url, title="테스트 뉴스", content="내용", source_id="hackernews",
        fetched_at=datetime.now(), upvotes=100, published_at=None,
        url_hash=hashlib.sha256(url.encode()).hexdigest(), lang="en",
    )


def _make_summary(url: str = "http://news.com/1") -> SummaryResult:
    return SummaryResult(
        item_url=url, summary_text="요약 완료", original_lang="en",
        summarizer_used="apex", translator_used="kanana", error=None,
    )


def test_pipeline_runs_without_exception() -> None:
    """파이프라인이 예외 없이 실행되어야 한다."""
    from news_pulse.orchestrator import Pipeline

    mock_db = MagicMock()
    config = _make_config()

    raw_item = _make_raw_item()
    news_item = _make_news_item()
    summary = _make_summary()
    send_result = SendResult(total=1, success_count=1, failed_chat_ids=[], errors={})

    with (
        patch("news_pulse.orchestrator.SystemMemoryGuard") as mock_guard_cls,
        patch("news_pulse.orchestrator.TelegramSubscriberPoller") as mock_poller_cls,
        patch("news_pulse.orchestrator.RssFetcher") as mock_rss_cls,
        patch("news_pulse.orchestrator.AlgoliaFetcher") as mock_algolia_cls,
        patch("news_pulse.orchestrator.RedditFetcher") as mock_reddit_cls,
        patch("news_pulse.orchestrator.GithubAtomFetcher") as mock_github_cls,
        patch("news_pulse.orchestrator.SqliteDedup") as mock_dedup_cls,
        patch("news_pulse.orchestrator.ChainedLanguageDetector") as mock_lang_cls,
        patch("news_pulse.orchestrator.FallbackChain") as mock_chain_cls,
        patch("news_pulse.orchestrator.ThresholdHotNewsDetector") as mock_hot_cls,
        patch("news_pulse.orchestrator.TelegramMessageFormatter") as mock_fmt_cls,
        patch("news_pulse.orchestrator.HttpTelegramSender") as mock_sender_cls,
        patch("news_pulse.orchestrator.SqliteRunLogger") as mock_logger_cls,
        patch("news_pulse.orchestrator.TelegramErrorNotifier") as mock_notifier_cls,
        patch("news_pulse.orchestrator.SqliteDataCleaner") as mock_cleaner_cls,
        patch("news_pulse.orchestrator.OllamaEngine") as mock_ollama_cls,
        patch("news_pulse.orchestrator.ClaudeCliEngine") as mock_claude_cls,
        patch("news_pulse.orchestrator.BlacklistFilter"),
        patch("news_pulse.orchestrator.TierRouter"),
        patch("news_pulse.orchestrator.PrioritySelector"),
    ):
        # 메모리 가드 설정
        mock_guard_cls.return_value.check.return_value = "local_llm"
        # 구독자 폴러
        mock_poller_cls.return_value.poll.return_value = []
        # 수집기 — RSS만 아이템 반환
        mock_rss_cls.return_value.fetch.return_value = [raw_item]
        mock_algolia_cls.return_value.fetch.return_value = []
        mock_reddit_cls.return_value.fetch.return_value = []
        mock_github_cls.return_value.fetch.return_value = []
        # Dedup
        mock_dedup_cls.return_value.filter_new.return_value = [news_item]
        # LanguageDetector
        mock_lang_cls.return_value.detect.return_value = news_item
        # FallbackChain — summarize, translate 모두 성공
        mock_chain = MagicMock()
        mock_chain.execute.return_value = summary
        mock_chain_cls.return_value = mock_chain

        # HotNewsDetector
        mock_hot_cls.return_value.detect.return_value = False
        # Formatter
        mock_fmt_cls.return_value.format.return_value = "포맷된 메시지"
        # Sender
        mock_sender_cls.return_value.send.return_value = send_result
        # RunLogger — 예외 없이 실행
        mock_logger_cls.return_value.log.return_value = None
        # Cleaner
        mock_cleaner_cls.return_value.clean.return_value = MagicMock()
        # Ollama
        mock_ollama_cls.return_value.load.return_value = None
        mock_ollama_cls.return_value.unload.return_value = None

        pipeline = Pipeline(config=config, db=mock_db)
        # 예외 없이 실행되어야 한다
        pipeline.run()

        # RunLogger.log가 호출되었는지 확인
        mock_logger_cls.return_value.log.assert_called_once()


def test_pipeline_calls_error_notifier_on_exception() -> None:
    """파이프라인 예외 시 ErrorNotifier가 호출되어야 한다."""
    from news_pulse.orchestrator import Pipeline

    mock_db = MagicMock()
    config = _make_config()

    with (
        patch("news_pulse.orchestrator.SystemMemoryGuard") as mock_guard_cls,
        patch("news_pulse.orchestrator.TelegramSubscriberPoller"),
        patch("news_pulse.orchestrator.RssFetcher") as mock_rss_cls,
        patch("news_pulse.orchestrator.AlgoliaFetcher") as mock_algolia_cls,
        patch("news_pulse.orchestrator.RedditFetcher") as mock_reddit_cls,
        patch("news_pulse.orchestrator.GithubAtomFetcher") as mock_github_cls,
        patch("news_pulse.orchestrator.SqliteDedup") as mock_dedup_cls,
        patch("news_pulse.orchestrator.ChainedLanguageDetector"),
        patch("news_pulse.orchestrator.FallbackChain"),
        patch("news_pulse.orchestrator.ThresholdHotNewsDetector"),
        patch("news_pulse.orchestrator.TelegramMessageFormatter"),
        patch("news_pulse.orchestrator.HttpTelegramSender"),
        patch("news_pulse.orchestrator.SqliteRunLogger") as mock_logger_cls,
        patch("news_pulse.orchestrator.TelegramErrorNotifier") as mock_notifier_cls,
        patch("news_pulse.orchestrator.SqliteDataCleaner"),
        patch("news_pulse.orchestrator.OllamaEngine"),
        patch("news_pulse.orchestrator.ClaudeCliEngine"),
        patch("news_pulse.orchestrator.BlacklistFilter"),
        patch("news_pulse.orchestrator.TierRouter"),
        patch("news_pulse.orchestrator.PrioritySelector"),
    ):
        mock_guard_cls.return_value.check.return_value = "local_llm"
        # Dedup에서 예외를 발생시켜 파이프라인 중단을 시뮬레이션
        mock_rss_cls.return_value.fetch.return_value = []
        mock_algolia_cls.return_value.fetch.return_value = []
        mock_reddit_cls.return_value.fetch.return_value = []
        mock_github_cls.return_value.fetch.return_value = []
        mock_dedup_cls.return_value.filter_new.side_effect = RuntimeError("DB 연결 실패")
        mock_logger_cls.return_value.log.return_value = None
        mock_notifier_cls.return_value.notify.return_value = None

        pipeline = Pipeline(config=config, db=mock_db)
        pipeline.run()  # 예외가 외부로 전파되지 않아야 한다

        # ErrorNotifier가 호출되었는지 확인
        mock_notifier_cls.return_value.notify.assert_called_once()
