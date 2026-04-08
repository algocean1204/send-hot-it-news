"""
Pipeline 오케스트레이터.

블럭을 DI로 조립하고 4개 원자 모듈(fetch/filter/summarize/send)을 순서대로 호출한다.
각 원자 모듈은 news_pulse/core/ 하위에 분리되어 있다.
"""
from __future__ import annotations
import logging, time
from datetime import datetime
from news_pulse.blocks.data_cleaner import SqliteDataCleaner
from news_pulse.blocks.dedup import SqliteDedup
from news_pulse.blocks.error_notifier import TelegramErrorNotifier
from news_pulse.blocks.fetcher.algolia_fetcher import AlgoliaFetcher
from news_pulse.blocks.fetcher.github_atom_fetcher import GithubAtomFetcher
from news_pulse.blocks.fetcher.reddit_fetcher import RedditFetcher
from news_pulse.blocks.fetcher.rss_fetcher import RssFetcher
from news_pulse.blocks.filter.blacklist_filter import BlacklistFilter
from news_pulse.blocks.filter.priority_selector import PrioritySelector
from news_pulse.blocks.filter.tier_router import TierRouter
from news_pulse.blocks.filter.whitelist_filter import WhitelistFilter
from news_pulse.blocks.hot_news_detector import ThresholdHotNewsDetector
from news_pulse.blocks.language_detector import ChainedLanguageDetector
from news_pulse.blocks.memory_guard import SystemMemoryGuard
from news_pulse.blocks.message_formatter import TelegramMessageFormatter
from news_pulse.blocks.model_engine.claude_cli_engine import ClaudeCliEngine
from news_pulse.blocks.model_engine.ollama_engine import OllamaEngine
from news_pulse.blocks.run_logger import SqliteRunLogger
from news_pulse.blocks.skip_detector import detect_missed
from news_pulse.blocks.subscriber_poller import TelegramSubscriberPoller
from news_pulse.blocks.summarizer.apex_summarizer import ApexSummarizer
from news_pulse.blocks.summarizer.claude_cli_summarizer import ClaudeCliSummarizer
from news_pulse.blocks.summarizer.kanana_summarizer import KananaSummarizer
from news_pulse.blocks.telegram_sender import HttpTelegramSender
from news_pulse.blocks.translator.claude_cli_translator import ClaudeCliTranslator
from news_pulse.blocks.translator.kanana_translator import KananaTranslator
from news_pulse.core.digest_pipeline import send_digest
from news_pulse.core.fallback_chain import FallbackChain
from news_pulse.core.fetch_pipeline import fetch_all
from news_pulse.core.filter_pipeline import apply_filters
from news_pulse.core.send_pipeline import send_messages
from news_pulse.core.summarize_pipeline import summarize_and_translate
from news_pulse.db.store import SqliteStore
from news_pulse.models.config import Config
from news_pulse.models.news import SummaryResult
from news_pulse.models.pipeline import MemoryStatus, PipelineResult
logger = logging.getLogger(__name__)


def _build_whitelist_filter(db: SqliteStore) -> WhitelistFilter:
    """DB에서 화이트리스트 키워드를 로드해 WhitelistFilter를 생성한다."""
    try:
        keywords = db.get_whitelist_keywords_set()
        return WhitelistFilter(keywords)
    except Exception as exc:
        logger.warning("화이트리스트 로드 실패, 비활성 필터 사용: %s", exc)
        return WhitelistFilter(set())


class Pipeline:
    """블럭을 DI로 조립해 4단계 원자 모듈을 순서대로 실행하는 얇은 오케스트레이터."""

    def __init__(self, config: Config, db: SqliteStore, ollama_engine: OllamaEngine | None = None) -> None:
        self._config = config
        self._db = db
        self._memory_guard = SystemMemoryGuard()
        self._subscriber_poller = TelegramSubscriberPoller(db)
        self._fetchers = [RssFetcher(), AlgoliaFetcher(), RedditFetcher(), GithubAtomFetcher()]
        self._dedup = SqliteDedup(db); self._lang_detector = ChainedLanguageDetector()
        whitelist = _build_whitelist_filter(db)
        self._filters = [BlacklistFilter(), TierRouter(whitelist_filter=whitelist), PrioritySelector()]
        self._ollama = ollama_engine or OllamaEngine(config.ollama_endpoint)
        self._claude_cli = ClaudeCliEngine()
        self._summarizer_chain: FallbackChain[SummaryResult] = FallbackChain([
            ApexSummarizer(model_name=config.apex_model_name),
            KananaSummarizer(model_name=config.kanana_model_name),
            ClaudeCliSummarizer(),
        ])
        self._translator_chain: FallbackChain[SummaryResult] = FallbackChain([
            KananaTranslator(model_name=config.kanana_model_name),
            ClaudeCliTranslator(),
        ])
        self._hot_detector = ThresholdHotNewsDetector(db); self._formatter = TelegramMessageFormatter()
        self._sender = HttpTelegramSender(db); self._run_logger = SqliteRunLogger(db)
        self._notifier = TelegramErrorNotifier(db); self._cleaner = SqliteDataCleaner(db)

    def run(self) -> PipelineResult:
        """메인 파이프라인을 실행하고 결과를 반환한다. 예외 시 ErrorNotifier를 호출한다."""
        start = time.monotonic(); run_at = datetime.now()
        has_error, error_summary, fetch_errors = False, None, 0
        fetched = dedup = filtered = summarized = sent = 0
        mem: MemoryStatus = "local_llm"
        try:
            # F05: 파이프라인 시작 시 스케줄 누락 감지
            detect_missed(self._db, run_at)
            mem = self._memory_guard.check(self._config)
            self._subscriber_poller.poll(self._config)
            raw_items, fetch_errors = fetch_all(self._fetchers, self._config)
            fetched = len(raw_items)
            items = self._dedup.filter_new(raw_items); dedup = len(items)
            items = [self._lang_detector.detect(i) for i in items]
            items = apply_filters(self._filters, items, self._config); filtered = len(items)
            if not items:
                logger.info("신규 아이템 없음, 파이프라인 종료")
            elif self._config.digest_enabled and datetime.now().hour != self._config.digest_hour:
                # 다이제스트 모드: 지정 시간이 아니면 요약만 하고 전송하지 않는다
                summarize_and_translate(
                    items, mem, self._ollama, self._claude_cli,
                    self._summarizer_chain, self._translator_chain,
                    self._config, store=self._db,
                )
                logger.info("다이제스트 모드 — 요약만 수행, 전송 보류")
            elif self._config.digest_enabled:
                # 다이제스트 시간 — 미전송 아이템 묶음 전송
                sent = send_digest(self._db, self._config, self._sender)
            else:
                results, summarized = summarize_and_translate(
                    items, mem, self._ollama, self._claude_cli,
                    self._summarizer_chain, self._translator_chain,
                    self._config, store=self._db,
                )
                sent = send_messages(items, results, self._hot_detector, self._formatter, self._sender, self._config)
            self._cleaner.clean(self._config)
        except Exception as exc:
            has_error, error_summary = True, str(exc)
            logger.exception("파이프라인 전체 예외 발생: %s", exc)
            self._notifier.notify(exc, {"module": "Pipeline"}, self._config)
        result = PipelineResult(
            run_at=run_at, fetched_count=fetched, dedup_count=dedup,
            filtered_count=filtered, summarized_count=summarized, sent_count=sent,
            elapsed_seconds=time.monotonic() - start, memory_status=mem,
            has_error=has_error, error_summary=error_summary, fetch_errors=fetch_errors,
        )
        self._run_logger.log(result)
        return result
