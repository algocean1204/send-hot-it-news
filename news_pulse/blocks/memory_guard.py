"""
블럭 2 — MemoryGuard.

가용 RAM을 측정해 로컬 LLM 사용 가능 여부를 결정한다.
임계값 미만이면 Claude CLI 폴백으로 전환한다.
"""
from __future__ import annotations

import logging
from typing import Protocol

import psutil

from news_pulse.models.config import Config
from news_pulse.models.pipeline import MemoryStatus

logger = logging.getLogger(__name__)

# GB 단위 변환 상수
_BYTES_PER_GB: float = 1024 ** 3


class MemoryGuardProtocol(Protocol):
    """MemoryGuard 인터페이스 정의."""

    def check(self, config: Config) -> MemoryStatus: ...


class SystemMemoryGuard:
    """psutil로 가용 RAM을 측정해 메모리 상태를 결정하는 구현체."""

    def check(self, config: Config) -> MemoryStatus:
        """
        가용 메모리를 측정하고 임계값과 비교한다.

        psutil 호출 자체가 실패하면 안전하게 claude_fallback을 반환한다.
        """
        try:
            return self._measure_and_decide(config.memory_threshold_gb)
        except Exception as exc:
            logger.warning("메모리 측정 실패, claude_fallback으로 전환: %s", exc)
            return "claude_fallback"

    def _measure_and_decide(self, threshold_gb: float) -> MemoryStatus:
        """가용 메모리를 GB로 환산해 상태를 반환한다."""
        available_bytes: int = psutil.virtual_memory().available
        available_gb: float = available_bytes / _BYTES_PER_GB
        logger.debug("가용 메모리: %.1f GB, 임계값: %.1f GB", available_gb, threshold_gb)
        if available_gb >= threshold_gb:
            return "local_llm"
        return "claude_fallback"
