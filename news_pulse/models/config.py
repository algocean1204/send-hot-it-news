"""
시스템 설정 dataclass 모듈.

Config는 전체 애플리케이션 설정을 담으며,
SourceConfig는 개별 뉴스 소스 설정을 표현한다.
"""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class SourceConfig:
    """개별 뉴스 소스 설정."""

    source_id: str          # 예: "geeknews", "hackernews"
    name: str               # 표시명
    url: str                # 피드/API URL
    source_type: str        # "rss" | "algolia" | "reddit" | "github_atom"
    tier: int               # 1 | 2 | 3 (우선순위 등급)
    language: str           # "ko" | "en"
    enabled: bool           # ON/OFF 활성화 여부
    is_custom: bool = False  # Flutter Source Wizard로 추가된 사용자 정의 소스 여부


@dataclass
class Config:
    """전체 애플리케이션 설정. ConfigLoader가 .env에서 읽어 생성한다."""

    # 텔레그램 설정
    bot_token: str
    admin_chat_id: str

    # DB 설정
    db_path: str

    # Ollama 모델 설정
    ollama_endpoint: str        # 기본: "http://localhost:11434"
    apex_model_name: str        # 기본: "apex-i-compact"
    kanana_model_name: str      # 기본: "kanana-2-30b"
    memory_threshold_gb: float  # 메모리 분기 임계값 (기본: 26.0)

    # 뉴스 소스 목록 (12개)
    sources: list[SourceConfig] = field(default_factory=list)

    # 소스별 할당 쿼터
    tier1_quota: int = 7
    tier2_quota: int = 1
    tier3_quota: int = 4
    tier3_hn_threshold: int = 50        # HN 업보트 임계값
    tier3_reddit_threshold: int = 25    # Reddit 업보트 임계값
    blacklist_keywords: list[str] = field(default_factory=list)

    # 보관 기간 (일 단위)
    processed_items_retention_days: int = 30
    run_history_retention_days: int = 90
    error_log_retention_days: int = 30
    health_check_retention_days: int = 7

    # 핫뉴스 판단 임계값
    hot_hn_threshold: int = 200
    hot_reddit_threshold: int = 80

    # 다이제스트 모드 설정 (F07)
    digest_enabled: bool = False  # True이면 지정 시간에만 묶어서 전송
    digest_hour: int = 9          # 다이제스트를 전송할 시각 (0-23)
