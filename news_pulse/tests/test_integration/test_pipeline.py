"""
파이프라인 통합 테스트.

외부 의존성(Ollama, Telegram, HTTP)을 mock으로 대체해
파이프라인 전체 흐름의 정상/실패/엣지 경로를 검증한다.
"""
from __future__ import annotations

import hashlib
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest

from news_pulse.models.config import Config, SourceConfig
from news_pulse.models.news import NewsItem, RawItem, SummaryResult
from news_pulse.models.telegram import SendResult


def _make_config() -> Config:
    """테스트용 Config 객체를 생성한다."""
    sources = [
        SourceConfig(
            source_id="hackernews", name="HN",
            url="http://hn.algolia.com/api/v1/search",
            source_type="algolia", tier=3, language="en", enabled=True,
        ),
        SourceConfig(
            source_id="geeknews", name="GeekNews",
            url="https://news.hada.io/rss",
            source_type="rss", tier=2, language="ko", enabled=True,
        ),
    ]
    return Config(
        bot_token="tok", admin_chat_id="admin1",
        db_path="/tmp/pipeline_test.db",
        ollama_endpoint="http://localhost:11434",
        apex_model_name="apex", kanana_model_name="kanana",
        memory_threshold_gb=26.0, sources=sources,
    )


def _make_raw(url: str, source_id: str = "hackernews") -> RawItem:
    """테스트용 RawItem을 생성한다."""
    return RawItem(
        url=url, title=f"기사 {url}", content="본문",
        source_id=source_id, fetched_at=datetime.now(),
        upvotes=100, published_at=None,
        url_hash=hashlib.sha256(url.encode()).hexdigest(),
    )


def _make_news(url: str, lang: str = "en", source_id: str = "hackernews") -> NewsItem:
    """테스트용 NewsItem을 생성한다."""
    return NewsItem(
        url=url, title=f"기사 {url}", content="본문",
        source_id=source_id, fetched_at=datetime.now(),
        upvotes=100, published_at=None,
        url_hash=hashlib.sha256(url.encode()).hexdigest(),
        lang=lang,
    )


def _pipeline_patches():
    """오케스트레이터 내부 블럭을 모두 mock으로 대체하는 컨텍스트 매니저."""
    return (
        patch("news_pulse.orchestrator.SystemMemoryGuard"),
        patch("news_pulse.orchestrator.TelegramSubscriberPoller"),
        patch("news_pulse.orchestrator.RssFetcher"),
        patch("news_pulse.orchestrator.AlgoliaFetcher"),
        patch("news_pulse.orchestrator.RedditFetcher"),
        patch("news_pulse.orchestrator.GithubAtomFetcher"),
        patch("news_pulse.orchestrator.SqliteDedup"),
        patch("news_pulse.orchestrator.ChainedLanguageDetector"),
        patch("news_pulse.orchestrator.FallbackChain"),
        patch("news_pulse.orchestrator.ThresholdHotNewsDetector"),
        patch("news_pulse.orchestrator.TelegramMessageFormatter"),
        patch("news_pulse.orchestrator.HttpTelegramSender"),
        patch("news_pulse.orchestrator.SqliteRunLogger"),
        patch("news_pulse.orchestrator.TelegramErrorNotifier"),
        patch("news_pulse.orchestrator.SqliteDataCleaner"),
        patch("news_pulse.orchestrator.OllamaEngine"),
        patch("news_pulse.orchestrator.ClaudeCliEngine"),
        patch("news_pulse.orchestrator.BlacklistFilter"),
        patch("news_pulse.orchestrator.TierRouter"),
        patch("news_pulse.orchestrator.PrioritySelector"),
    )


def test_파이프라인_신규_아이템_없음_정상종료() -> None:
    """수집 후 dedup 결과가 빈 리스트일 때 파이프라인이 정상 종료되어야 한다."""
    from news_pulse.orchestrator import Pipeline

    patches = _pipeline_patches()
    with patches[0] as mg, patches[1], patches[2] as rss, \
         patches[3] as alg, patches[4] as rdt, patches[5] as gh, \
         patches[6] as dd, patches[7], patches[8] as fc, \
         patches[9], patches[10], patches[11], \
         patches[12] as rl, patches[13], patches[14] as cl, \
         patches[15], patches[16], patches[17], patches[18], patches[19]:

        mg.return_value.check.return_value = "local_llm"
        rss.return_value.fetch.return_value = []
        alg.return_value.fetch.return_value = []
        rdt.return_value.fetch.return_value = []
        gh.return_value.fetch.return_value = []
        dd.return_value.filter_new.return_value = []
        rl.return_value.log.return_value = None
        cl.return_value.clean.return_value = MagicMock()

        pipeline = Pipeline(config=_make_config(), db=MagicMock())
        pipeline.run()

        # FallbackChain.execute는 호출되지 않아야 한다
        fc.return_value.execute.assert_not_called()
        # RunLogger.log는 호출되어야 한다
        rl.return_value.log.assert_called_once()


def test_파이프라인_claude_fallback_모드() -> None:
    """메모리 부족 시 claude_fallback 모드로 파이프라인이 실행되어야 한다."""
    from news_pulse.orchestrator import Pipeline

    patches = _pipeline_patches()
    with patches[0] as mg, patches[1], patches[2] as rss, \
         patches[3] as alg, patches[4] as rdt, patches[5] as gh, \
         patches[6] as dd, patches[7] as ld, patches[8] as fc, \
         patches[9] as hd, patches[10] as fmt, patches[11] as snd, \
         patches[12] as rl, patches[13], patches[14] as cl, \
         patches[15] as ollama, patches[16] as claude, \
         patches[17], patches[18], patches[19]:

        mg.return_value.check.return_value = "claude_fallback"
        rss.return_value.fetch.return_value = [_make_raw("http://a.com")]
        alg.return_value.fetch.return_value = []
        rdt.return_value.fetch.return_value = []
        gh.return_value.fetch.return_value = []
        news = _make_news("http://a.com")
        dd.return_value.filter_new.return_value = [news]
        ld.return_value.detect.return_value = news
        summary = SummaryResult(
            item_url="http://a.com", summary_text="요약",
            original_lang="en", summarizer_used="claude",
            translator_used=None, error=None,
        )
        fc.return_value.execute.return_value = summary
        hd.return_value.detect.return_value = False
        fmt.return_value.format.return_value = "메시지"
        snd.return_value.send.return_value = SendResult(
            total=1, success_count=1, failed_chat_ids=[], errors={},
        )
        rl.return_value.log.return_value = None
        cl.return_value.clean.return_value = MagicMock()

        pipeline = Pipeline(config=_make_config(), db=MagicMock())
        pipeline.run()

        # claude_fallback 모드에서는 ollama.load가 호출되지 않아야 한다
        ollama.return_value.load.assert_not_called()


def test_파이프라인_한국어_영어_혼합_아이템() -> None:
    """KO/EN 혼합 아이템이 모두 처리되어야 한다."""
    from news_pulse.orchestrator import Pipeline

    patches = _pipeline_patches()
    with patches[0] as mg, patches[1], patches[2] as rss, \
         patches[3] as alg, patches[4] as rdt, patches[5] as gh, \
         patches[6] as dd, patches[7] as ld, patches[8] as fc, \
         patches[9] as hd, patches[10] as fmt, patches[11] as snd, \
         patches[12] as rl, patches[13], patches[14] as cl, \
         patches[15], patches[16], \
         patches[17] as bf, patches[18] as tr, patches[19] as ps:

        mg.return_value.check.return_value = "local_llm"
        ko_raw = _make_raw("http://ko.com", "geeknews")
        en_raw = _make_raw("http://en.com", "hackernews")
        rss.return_value.fetch.return_value = [ko_raw, en_raw]
        alg.return_value.fetch.return_value = []
        rdt.return_value.fetch.return_value = []
        gh.return_value.fetch.return_value = []

        ko_news = _make_news("http://ko.com", "ko", "geeknews")
        en_news = _make_news("http://en.com", "en", "hackernews")
        dd.return_value.filter_new.return_value = [ko_news, en_news]
        ld.return_value.detect.side_effect = [ko_news, en_news]

        # 필터가 아이템을 그대로 통과시키도록 설정
        bf.return_value.apply.side_effect = lambda items, cfg: items
        tr.return_value.apply.side_effect = lambda items, cfg: items
        ps.return_value.apply.side_effect = lambda items, cfg: items

        ko_summary = SummaryResult(
            item_url="http://ko.com", summary_text="한국어 요약",
            original_lang="ko", summarizer_used="apex",
            translator_used=None, error=None,
        )
        en_summary = SummaryResult(
            item_url="http://en.com", summary_text="EN summary",
            original_lang="en", summarizer_used="apex",
            translator_used="kanana", error=None,
        )
        fc.return_value.execute.side_effect = [
            ko_summary, en_summary, ko_summary, en_summary,
        ]
        hd.return_value.detect.return_value = False
        fmt.return_value.format.return_value = "msg"
        snd.return_value.send.return_value = SendResult(
            total=1, success_count=1, failed_chat_ids=[], errors={},
        )
        rl.return_value.log.return_value = None
        cl.return_value.clean.return_value = MagicMock()

        pipeline = Pipeline(config=_make_config(), db=MagicMock())
        pipeline.run()

        # 요약 + 번역으로 FallbackChain.execute가 4회 호출 (2 summarize + 2 translate)
        assert fc.return_value.execute.call_count == 4


def test_파이프라인_요약_실패시_에러_결과_포함() -> None:
    """요약 실패 시 에러가 포함된 SummaryResult를 생성해야 한다."""
    from news_pulse.orchestrator import Pipeline

    patches = _pipeline_patches()
    with patches[0] as mg, patches[1], patches[2] as rss, \
         patches[3] as alg, patches[4] as rdt, patches[5] as gh, \
         patches[6] as dd, patches[7] as ld, patches[8] as fc, \
         patches[9] as hd, patches[10] as fmt, patches[11] as snd, \
         patches[12] as rl, patches[13], patches[14] as cl, \
         patches[15], patches[16], patches[17], patches[18], patches[19]:

        mg.return_value.check.return_value = "local_llm"
        rss.return_value.fetch.return_value = [_make_raw("http://fail.com")]
        alg.return_value.fetch.return_value = []
        rdt.return_value.fetch.return_value = []
        gh.return_value.fetch.return_value = []
        news = _make_news("http://fail.com")
        dd.return_value.filter_new.return_value = [news]
        ld.return_value.detect.return_value = news
        # 요약 시 예외 발생 -> 번역 시 정상 반환
        fc.return_value.execute.side_effect = [
            RuntimeError("모델 응답 없음"),
            SummaryResult(
                item_url="http://fail.com", summary_text="",
                original_lang="en", summarizer_used="none",
                translator_used=None, error="모델 응답 없음",
            ),
        ]
        hd.return_value.detect.return_value = False
        fmt.return_value.format.return_value = "msg"
        snd.return_value.send.return_value = SendResult(
            total=1, success_count=1, failed_chat_ids=[], errors={},
        )
        rl.return_value.log.return_value = None
        cl.return_value.clean.return_value = MagicMock()

        pipeline = Pipeline(config=_make_config(), db=MagicMock())
        pipeline.run()

        # 파이프라인이 예외 없이 완료되어야 한다
        rl.return_value.log.assert_called_once()
