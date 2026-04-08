"""
KananaSummarizer 테스트.

APEX 폴백 시 Kanana 모델 로드 확인, 콘텐츠 잘림,
요약 실패 시 예외 전파를 검증한다.
"""
from __future__ import annotations

import hashlib
from datetime import datetime
from unittest.mock import MagicMock

import pytest

from news_pulse.blocks.summarizer.kanana_summarizer import KananaSummarizer
from news_pulse.models.news import NewsItem


def _news(
    content: str | None = "기사 본문",
    title: str = "테스트 기사",
) -> NewsItem:
    """테스트용 NewsItem을 생성한다."""
    url = "http://test.com/kanana"
    return NewsItem(
        url=url, title=title, content=content,
        source_id="hackernews", fetched_at=datetime.now(),
        upvotes=100, published_at=None,
        url_hash=hashlib.sha256(url.encode()).hexdigest(),
        lang="en",
    )


def test_정상_요약_반환() -> None:
    """정상 요약 시 SummaryResult를 올바르게 반환해야 한다."""
    engine = MagicMock()
    engine.generate.return_value = "Kanana 요약 결과"

    s = KananaSummarizer()
    result = s.summarize(_news(), engine)

    assert result.summary_text == "Kanana 요약 결과"
    assert result.summarizer_used == "KananaSummarizer"
    assert result.error is None


def test_Kanana_모델_로드_호출() -> None:
    """summarize 호출 시 Kanana 모델이 로드되어야 한다."""
    engine = MagicMock()
    engine.generate.return_value = "result"

    s = KananaSummarizer(model_name="kanana-custom")
    s.summarize(_news(), engine)

    engine.load.assert_called_once_with("kanana-custom", keep_alive=0)


def test_2000자_콘텐츠_잘림() -> None:
    """2000자 초과 콘텐츠가 잘려서 프롬프트에 포함되어야 한다."""
    engine = MagicMock()
    engine.generate.return_value = "요약"

    long_content = "가" * 5000
    s = KananaSummarizer()
    s.summarize(_news(content=long_content), engine)

    prompt = engine.generate.call_args[0][0]
    # 프롬프트에 5000자 원본이 아닌 2000자 잘린 내용이 포함되어야 한다
    assert "가" * 2000 in prompt
    assert "가" * 2001 not in prompt


def test_content_None_시_제목_사용() -> None:
    """content가 None일 때 제목을 대신 사용해야 한다."""
    engine = MagicMock()
    engine.generate.return_value = "요약"

    s = KananaSummarizer()
    s.summarize(_news(content=None, title="제목만 있는 기사"), engine)

    prompt = engine.generate.call_args[0][0]
    assert "제목만 있는 기사" in prompt


def test_실패시_예외_전파() -> None:
    """요약 실패 시 예외가 그대로 전파되어야 한다 (폴백체인이 처리)."""
    engine = MagicMock()
    engine.generate.side_effect = RuntimeError("모델 응답 없음")

    s = KananaSummarizer()
    with pytest.raises(RuntimeError, match="모델 응답 없음"):
        s.summarize(_news(), engine)
