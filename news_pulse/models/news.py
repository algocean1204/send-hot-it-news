"""
뉴스 아이템 관련 dataclass 모듈.

파이프라인의 각 단계에서 뉴스 데이터를 전달하는 데이터 구조를 정의한다.
RawItem -> NewsItem -> SummaryResult 순서로 파이프라인을 흐른다.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass
class RawItem:
    """수집 단계에서 생성되는 원시 뉴스 아이템. Fetcher가 반환한다."""

    url: str
    title: str
    content: str | None
    source_id: str          # 소스 식별자 (예: "hackernews", "geeknews")
    fetched_at: datetime
    upvotes: int | None     # Reddit/HN만 존재
    published_at: datetime | None
    url_hash: str           # SHA-256(url) — Dedup에서 사용


@dataclass
class NewsItem:
    """언어 감지 후 생성되는 뉴스 아이템. LanguageDetector가 lang을 추가한다."""

    url: str
    title: str
    content: str | None
    source_id: str
    fetched_at: datetime
    upvotes: int | None
    published_at: datetime | None
    url_hash: str
    lang: str               # "ko" | "en". LanguageDetector가 결정
    db_id: int | None = None  # Dedup 삽입 후 할당되는 processed_items.id


@dataclass
class SummaryResult:
    """요약/번역 결과. Summarizer + Translator 조합 후 생성된다."""

    item_url: str
    summary_text: str | None    # 요약 텍스트 (한국어). 요약 실패 시 None
    original_lang: str          # 원본 언어 ("ko" | "en")
    summarizer_used: str        # 사용된 Summarizer 구현체명
    translator_used: str | None # 사용된 Translator 구현체명. 한국어 소스는 None
    error: str | None           # 에러 발생 시 메시지
