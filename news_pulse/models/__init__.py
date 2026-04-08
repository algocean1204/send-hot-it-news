"""
공유 데이터 모델 패키지.

모든 블럭 간 통신에 사용되는 dataclass 정의를 포함한다.
backend-api와 app-frontend 모두 이 패키지에 의존한다.
"""
from __future__ import annotations

from news_pulse.models.config import Config, SourceConfig
from news_pulse.models.news import NewsItem, RawItem, SummaryResult
from news_pulse.models.pipeline import CleanupResult, MemoryStatus, PipelineResult
from news_pulse.models.telegram import SendResult, SubscriberEvent
from news_pulse.models.health import HealthReport, HealthStatus

__all__ = [
    "Config",
    "SourceConfig",
    "RawItem",
    "NewsItem",
    "SummaryResult",
    "PipelineResult",
    "CleanupResult",
    "MemoryStatus",
    "SubscriberEvent",
    "SendResult",
    "HealthStatus",
    "HealthReport",
]
