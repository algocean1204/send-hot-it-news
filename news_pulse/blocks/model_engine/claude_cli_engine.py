"""
ClaudeCliEngine — Claude CLI subprocess 기반 LLM 엔진.

`claude -p --bare` subprocess를 호출해 응답을 받는다.
load/unload는 불필요하며 is_available()은 shutil.which('claude')로 확인한다.
"""
from __future__ import annotations

import logging
import shutil
import subprocess

logger = logging.getLogger(__name__)

# Claude CLI 기본 명령어
_CLAUDE_CMD = "claude"
# subprocess 타임아웃 (초) — Claude API 응답 시간 고려
_TIMEOUT = 120


class ClaudeCliEngine:
    """Claude CLI를 subprocess로 실행하는 폴백 엔진."""

    def is_available(self) -> bool:
        """PATH에서 claude 실행파일을 찾을 수 있는지 확인한다."""
        return shutil.which(_CLAUDE_CMD) is not None

    def load(self, model_name: str, keep_alive: int = 0) -> None:
        """Claude CLI는 로드 불필요. 호환성을 위해 no-op으로 구현."""
        logger.debug("ClaudeCliEngine: load() 호출 (no-op), model=%s", model_name)

    def generate(self, prompt: str, options: dict[str, object]) -> str:
        """claude -p --bare subprocess를 실행해 응답 텍스트를 반환한다.

        프롬프트를 stdin으로 전달한다 — 인수로 전달 시 셸 이스케이프 문제와
        ARG_MAX 제한이 발생할 수 있다.
        """
        result = subprocess.run(
            [_CLAUDE_CMD, "-p", "--bare"],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=_TIMEOUT,
            check=True,
        )
        return result.stdout.strip()

    def unload(self, model_name: str) -> None:
        """Claude CLI는 언로드 불필요. 호환성을 위해 no-op으로 구현."""
        logger.debug("ClaudeCliEngine: unload() 호출 (no-op), model=%s", model_name)
