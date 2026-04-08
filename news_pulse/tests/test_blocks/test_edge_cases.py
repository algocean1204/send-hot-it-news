"""
엣지 케이스 테스트.

빈 응답, 잘못된 JSON, 유니코드/이모지, 긴 콘텐츠 잘림,
중복 URL 해시, 누락된 환경변수 등 경계 조건을 검증한다.
"""
from __future__ import annotations

import hashlib
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest

from news_pulse.models.config import Config, SourceConfig
from news_pulse.models.news import NewsItem, RawItem, SummaryResult


def _config() -> Config:
    """테스트용 Config 객체를 생성한다."""
    return Config(
        bot_token="tok", admin_chat_id="admin1",
        db_path="/tmp/edge.db", ollama_endpoint="http://localhost:11434",
        apex_model_name="apex", kanana_model_name="kanana",
        memory_threshold_gb=26.0, sources=[],
    )


def _news(
    url: str = "http://test.com",
    title: str = "Test",
    content: str | None = "content",
    source_id: str = "hackernews",
    lang: str = "en",
    upvotes: int | None = 50,
) -> NewsItem:
    """테스트용 NewsItem을 생성한다."""
    return NewsItem(
        url=url, title=title, content=content,
        source_id=source_id, fetched_at=datetime.now(),
        upvotes=upvotes, published_at=None,
        url_hash=hashlib.sha256(url.encode()).hexdigest(),
        lang=lang,
    )


# -- 유니코드/이모지 제목 테스트 -- #

def test_유니코드_이모지_제목_포맷() -> None:
    """이모지가 포함된 제목이 MessageFormatter에서 정상 처리되어야 한다."""
    from news_pulse.blocks.message_formatter import TelegramMessageFormatter

    item = _news(title="AI 혁명 시작 LLM")
    result = SummaryResult(
        item_url=item.url, summary_text="요약 텍스트",
        original_lang="ko", summarizer_used="apex",
        translator_used=None, error=None,
    )
    fmt = TelegramMessageFormatter()
    msg = fmt.format(item, result, is_hot=False)
    assert "AI" in msg
    assert "LLM" in msg


def test_유니코드_CJK_제목_블랙리스트() -> None:
    """한글/중국어/일본어 키워드가 블랙리스트 필터에서 정상 매칭되어야 한다."""
    from news_pulse.blocks.filter.blacklist_filter import BlacklistFilter

    config = _config()
    config.blacklist_keywords = ["스팸"]
    items = [
        _news(title="AI 스팸 광고", url="http://1.com"),
        _news(title="정상 뉴스", url="http://2.com"),
    ]
    bf = BlacklistFilter()
    result = bf.apply(items, config)
    assert len(result) == 1
    assert result[0].title == "정상 뉴스"


# -- 매우 긴 콘텐츠 잘림 테스트 -- #

def test_긴_콘텐츠_요약기_잘림() -> None:
    """2000자 초과 콘텐츠가 ApexSummarizer에서 잘려서 전달되어야 한다."""
    from news_pulse.blocks.summarizer.apex_summarizer import ApexSummarizer

    long_content = "A" * 5000
    item = _news(content=long_content)
    engine = MagicMock()
    engine.generate.return_value = "요약 결과"

    s = ApexSummarizer()
    result = s.summarize(item, engine)

    # generate에 전달된 프롬프트에 원본 5000자가 아닌 잘린 내용이 포함되어야 한다
    call_args = engine.generate.call_args[0][0]
    assert len(call_args) < 5000
    assert result.summary_text == "요약 결과"


# -- 중복 URL 해시 테스트 -- #

def test_동일_URL_동일_해시() -> None:
    """동일한 URL은 항상 같은 해시를 생성해야 한다."""
    url = "https://example.com/article/123"
    h1 = hashlib.sha256(url.encode()).hexdigest()
    h2 = hashlib.sha256(url.encode()).hexdigest()
    assert h1 == h2


def test_다른_URL_다른_해시() -> None:
    """다른 URL은 다른 해시를 생성해야 한다."""
    h1 = hashlib.sha256("http://a.com".encode()).hexdigest()
    h2 = hashlib.sha256("http://b.com".encode()).hexdigest()
    assert h1 != h2


# -- 빈 입력 데이터 테스트 -- #

def test_빈_아이템_필터체인() -> None:
    """빈 리스트가 모든 필터를 통과해도 빈 리스트를 반환해야 한다."""
    from news_pulse.blocks.filter.blacklist_filter import BlacklistFilter
    from news_pulse.blocks.filter.priority_selector import PrioritySelector
    from news_pulse.blocks.filter.tier_router import TierRouter

    config = _config()
    items: list[NewsItem] = []
    assert BlacklistFilter().apply(items, config) == []
    assert TierRouter().apply(items, config) == []
    assert PrioritySelector().apply(items, config) == []


# -- content가 None인 경우 -- #

def test_content_None_요약기_제목_사용() -> None:
    """content가 None일 때 제목을 대신 사용해 요약해야 한다."""
    from news_pulse.blocks.summarizer.apex_summarizer import ApexSummarizer

    item = _news(content=None, title="제목만 있는 기사")
    engine = MagicMock()
    engine.generate.return_value = "요약"

    s = ApexSummarizer()
    result = s.summarize(item, engine)
    call_prompt = engine.generate.call_args[0][0]
    assert "제목만 있는 기사" in call_prompt


# -- 번역기 빈 summary_text 처리 -- #

def test_번역기_빈_summary_text_원본_반환() -> None:
    """summary_text가 빈 문자열일 때 번역을 건너뛰고 원본을 반환해야 한다."""
    from news_pulse.blocks.translator.kanana_translator import KananaTranslator

    result = SummaryResult(
        item_url="http://test.com", summary_text="",
        original_lang="en", summarizer_used="apex",
        translator_used=None, error=None,
    )
    engine = MagicMock()
    kt = KananaTranslator()
    translated = kt.translate(result, engine)
    # 빈 텍스트이므로 generate가 호출되지 않아야 한다
    engine.generate.assert_not_called()
    assert translated.summary_text == ""


# -- 환경변수 누락 테스트 -- #

def test_DB_PATH_누락시_ValueError() -> None:
    """DB_PATH 환경변수가 없으면 ValueError가 발생해야 한다."""
    from news_pulse.blocks.config_loader import EnvConfigLoader

    with patch.dict("os.environ", {"BOT_TOKEN": "tok", "ADMIN_CHAT_ID": "123"}, clear=True):
        loader = EnvConfigLoader(env_path="/nonexistent/.env")
        with pytest.raises(ValueError, match="DB_PATH"):
            loader.load()


# -- FallbackChain 빈 구현체 리스트 테스트 -- #

def test_폴백체인_빈_리스트_RuntimeError() -> None:
    """구현체 목록이 비어있으면 RuntimeError가 발생해야 한다."""
    from news_pulse.core.fallback_chain import FallbackChain

    chain = FallbackChain([])
    with pytest.raises(RuntimeError, match="비어 있어"):
        chain.execute("summarize")
