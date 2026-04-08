"""
데이터 모델 테스트.

dataclass 생성, 기본값, 직렬화/역직렬화를 검증한다.
"""
from __future__ import annotations

import dataclasses
from datetime import datetime

import pytest

from news_pulse.models.config import Config, SourceConfig
from news_pulse.models.health import HealthReport, HealthStatus
from news_pulse.models.news import NewsItem, RawItem, SummaryResult
from news_pulse.models.pipeline import CleanupResult, PipelineResult
from news_pulse.models.telegram import SendResult, SubscriberEvent


class TestSourceConfig:
    """SourceConfig dataclass 테스트."""

    def test_생성_정상(self) -> None:
        """필수 필드로 정상 생성되는지 확인한다."""
        src = SourceConfig(
            source_id="hackernews",
            name="Hacker News",
            url="https://hn.algolia.com/api/v1/search_by_date",
            source_type="algolia",
            tier=1,
            language="en",
            enabled=True,
        )
        assert src.source_id == "hackernews"
        assert src.tier == 1
        assert src.enabled is True

    def test_dict_변환(self) -> None:
        """dataclasses.asdict()로 딕셔너리 변환이 가능한지 확인한다."""
        src = SourceConfig("geeknews", "GeekNews", "https://feeds.feedburner.com/GeekNews", "rss", 1, "ko", True)
        d = dataclasses.asdict(src)
        assert d["source_id"] == "geeknews"
        assert d["language"] == "ko"


class TestConfig:
    """Config dataclass 테스트."""

    def test_기본값_확인(self) -> None:
        """선택적 필드의 기본값이 올바른지 확인한다."""
        cfg = Config(
            bot_token="token",
            admin_chat_id="12345",
            db_path="/tmp/test.db",
            ollama_endpoint="http://localhost:11434",
            apex_model_name="apex-i-compact",
            kanana_model_name="kanana-2-30b",
            memory_threshold_gb=26.0,
        )
        assert cfg.tier1_quota == 7
        assert cfg.tier2_quota == 1
        assert cfg.tier3_quota == 4
        assert cfg.hot_hn_threshold == 200
        assert cfg.sources == []
        assert cfg.blacklist_keywords == []


class TestRawItem:
    """RawItem dataclass 테스트."""

    def test_생성_선택_필드_none(self) -> None:
        """content, upvotes, published_at이 None인 경우도 생성 가능해야 한다."""
        now = datetime.now()
        item = RawItem(
            url="https://example.com/post/1",
            title="Test Article",
            content=None,
            source_id="geeknews",
            fetched_at=now,
            upvotes=None,
            published_at=None,
            url_hash="abc123hash",
        )
        assert item.content is None
        assert item.upvotes is None


class TestNewsItem:
    """NewsItem dataclass 테스트."""

    def test_lang_필드_존재(self) -> None:
        """RawItem과 달리 lang 필드가 있어야 한다."""
        now = datetime.now()
        item = NewsItem(
            url="https://example.com",
            title="Title",
            content="Content",
            source_id="hackernews",
            fetched_at=now,
            upvotes=100,
            published_at=now,
            url_hash="hashval",
            lang="en",
        )
        assert item.lang == "en"
        assert hasattr(item, "lang")


class TestSummaryResult:
    """SummaryResult dataclass 테스트."""

    def test_오류_없는_경우(self) -> None:
        """정상 요약 결과 생성을 확인한다."""
        result = SummaryResult(
            item_url="https://example.com",
            summary_text="요약 텍스트입니다.",
            original_lang="en",
            summarizer_used="ApexSummarizer",
            translator_used="ApexTranslator",
            error=None,
        )
        assert result.error is None
        assert result.translator_used == "ApexTranslator"

    def test_한국어_소스_translator_none(self) -> None:
        """한국어 소스는 translator_used가 None이어야 한다."""
        result = SummaryResult(
            item_url="https://geeknews.kr/item/1",
            summary_text="이미 한국어 요약.",
            original_lang="ko",
            summarizer_used="KananaSummarizer",
            translator_used=None,
            error=None,
        )
        assert result.translator_used is None


class TestPipelineResult:
    """PipelineResult dataclass 테스트."""

    def test_memory_status_값(self) -> None:
        """MemoryStatus 리터럴 타입이 올바른지 확인한다."""
        result = PipelineResult(
            run_at=datetime.now(),
            fetched_count=12,
            dedup_count=10,
            filtered_count=8,
            summarized_count=8,
            sent_count=8,
            elapsed_seconds=45.3,
            memory_status="local_llm",
            has_error=False,
            error_summary=None,
        )
        assert result.memory_status == "local_llm"

    def test_claude_fallback_상태(self) -> None:
        """claude_fallback 상태도 정상 생성되는지 확인한다."""
        result = PipelineResult(
            run_at=datetime.now(),
            fetched_count=5,
            dedup_count=5,
            filtered_count=3,
            summarized_count=3,
            sent_count=3,
            elapsed_seconds=120.0,
            memory_status="claude_fallback",
            has_error=False,
            error_summary=None,
        )
        assert result.memory_status == "claude_fallback"


class TestCleanupResult:
    """CleanupResult dataclass 테스트."""

    def test_생성(self) -> None:
        """정리 결과 생성을 확인한다."""
        result = CleanupResult(
            processed_items_deleted=15,
            run_history_deleted=3,
            error_log_deleted=5,
            health_check_deleted=20,
            cleaned_at=datetime.now(),
        )
        assert result.processed_items_deleted == 15


class TestSubscriberEvent:
    """SubscriberEvent dataclass 테스트."""

    def test_구독_이벤트(self) -> None:
        """구독 이벤트 생성을 확인한다."""
        event = SubscriberEvent(
            chat_id="987654321",
            username="user123",
            event_type="subscribe",
            occurred_at=datetime.now(),
            update_id=100001,
        )
        assert event.event_type == "subscribe"

    def test_해제_이벤트(self) -> None:
        """해제 이벤트 생성을 확인한다."""
        event = SubscriberEvent(
            chat_id="987654321",
            username=None,
            event_type="unsubscribe",
            occurred_at=datetime.now(),
            update_id=100002,
        )
        assert event.username is None
        assert event.event_type == "unsubscribe"


class TestSendResult:
    """SendResult dataclass 테스트."""

    def test_기본값_빈_목록(self) -> None:
        """실패 목록과 에러 딕셔너리의 기본값이 빈 컨테이너인지 확인한다."""
        result = SendResult(total=5, success_count=5)
        assert result.failed_chat_ids == []
        assert result.errors == {}

    def test_실패_포함(self) -> None:
        """일부 실패 시 데이터 구조를 확인한다."""
        result = SendResult(
            total=5,
            success_count=4,
            failed_chat_ids=["111"],
            errors={"111": "Forbidden"},
        )
        assert len(result.failed_chat_ids) == 1


class TestHealthModels:
    """HealthStatus / HealthReport dataclass 테스트."""

    def test_health_status_생성(self) -> None:
        """HealthStatus 생성을 확인한다."""
        status = HealthStatus(name="ollama", status="OK", message="모델 응답 정상")
        assert status.status == "OK"

    def test_health_report_items_기본값(self) -> None:
        """items 기본값이 빈 리스트인지 확인한다."""
        report = HealthReport(checked_at=datetime.now(), overall="OK")
        assert report.items == []

    def test_health_report_복수_items(self) -> None:
        """복수 HealthStatus를 담은 리포트 생성을 확인한다."""
        now = datetime.now()
        report = HealthReport(
            checked_at=now,
            overall="WARN",
            items=[
                HealthStatus("ollama", "OK", "정상"),
                HealthStatus("geeknews", "WARN", "응답 지연"),
            ],
        )
        assert len(report.items) == 2
        assert report.overall == "WARN"
