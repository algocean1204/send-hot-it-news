"""
MemoryGuard 단위 테스트.

임계값 경계 및 psutil 실패 시 claude_fallback 반환을 검증한다.
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

from news_pulse.blocks.memory_guard import SystemMemoryGuard
from news_pulse.models.config import Config


def _make_config(threshold_gb: float) -> Config:
    """테스트용 최소 Config를 생성한다."""
    return Config(
        bot_token="tok",
        admin_chat_id="1",
        db_path="/tmp/test.db",
        ollama_endpoint="http://localhost:11434",
        apex_model_name="apex",
        kanana_model_name="kanana",
        memory_threshold_gb=threshold_gb,
    )


def test_returns_local_llm_when_above_threshold() -> None:
    """가용 메모리가 임계값 이상이면 local_llm을 반환해야 한다."""
    guard = SystemMemoryGuard()
    config = _make_config(threshold_gb=10.0)
    mock_vm = MagicMock()
    # 20GB = 20 * 1024^3 bytes
    mock_vm.available = 20 * (1024 ** 3)

    with patch("news_pulse.blocks.memory_guard.psutil.virtual_memory", return_value=mock_vm):
        result = guard.check(config)

    assert result == "local_llm"


def test_returns_claude_fallback_when_below_threshold() -> None:
    """가용 메모리가 임계값 미만이면 claude_fallback을 반환해야 한다."""
    guard = SystemMemoryGuard()
    config = _make_config(threshold_gb=26.0)
    mock_vm = MagicMock()
    # 10GB — 임계값(26GB) 미만
    mock_vm.available = 10 * (1024 ** 3)

    with patch("news_pulse.blocks.memory_guard.psutil.virtual_memory", return_value=mock_vm):
        result = guard.check(config)

    assert result == "claude_fallback"


def test_returns_claude_fallback_on_psutil_error() -> None:
    """psutil 호출 실패 시 안전하게 claude_fallback을 반환해야 한다."""
    guard = SystemMemoryGuard()
    config = _make_config(threshold_gb=26.0)

    with patch(
        "news_pulse.blocks.memory_guard.psutil.virtual_memory",
        side_effect=RuntimeError("psutil 오류"),
    ):
        result = guard.check(config)

    assert result == "claude_fallback"


def test_boundary_equal_threshold_returns_local_llm() -> None:
    """가용 메모리가 정확히 임계값과 같으면 local_llm을 반환해야 한다."""
    guard = SystemMemoryGuard()
    threshold_gb = 26.0
    config = _make_config(threshold_gb=threshold_gb)
    mock_vm = MagicMock()
    mock_vm.available = int(threshold_gb * (1024 ** 3))

    with patch("news_pulse.blocks.memory_guard.psutil.virtual_memory", return_value=mock_vm):
        result = guard.check(config)

    assert result == "local_llm"
