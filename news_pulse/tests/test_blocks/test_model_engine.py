"""
ModelEngine 단위 테스트.

OllamaEngine 연결 확인, ClaudeCliEngine 가용성 검사를 mock으로 검증한다.
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

from news_pulse.blocks.model_engine.claude_cli_engine import ClaudeCliEngine
from news_pulse.blocks.model_engine.ollama_engine import OllamaEngine


class TestOllamaEngine:
    def test_is_available_returns_true_on_200(self) -> None:
        """Ollama 서버가 200을 반환하면 is_available()이 True여야 한다."""
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        with patch("news_pulse.blocks.model_engine.ollama_engine.httpx.get", return_value=mock_resp):
            engine = OllamaEngine()
            assert engine.is_available() is True

    def test_is_available_returns_false_on_error(self) -> None:
        """Ollama 서버 연결 실패 시 is_available()이 False여야 한다."""
        with patch(
            "news_pulse.blocks.model_engine.ollama_engine.httpx.get",
            side_effect=ConnectionError("연결 거부"),
        ):
            engine = OllamaEngine()
            assert engine.is_available() is False

    def test_generate_returns_response(self) -> None:
        """generate()가 Ollama API 응답 텍스트를 반환해야 한다."""
        mock_resp = MagicMock()
        mock_resp.json.return_value = {"response": "요약된 텍스트"}
        mock_resp.raise_for_status = MagicMock()

        with patch("news_pulse.blocks.model_engine.ollama_engine.httpx.post", return_value=mock_resp):
            engine = OllamaEngine()
            engine.load("apex-model")
            result = engine.generate("프롬프트", {"temperature": 0.3})

        assert result == "요약된 텍스트"

    def test_generate_requires_load_first(self) -> None:
        """load() 없이 generate() 호출 시 RuntimeError가 발생해야 한다."""
        import pytest
        engine = OllamaEngine()
        with pytest.raises(RuntimeError):
            engine.generate("prompt", {})


class TestClaudeCliEngine:
    def test_is_available_true_when_claude_found(self) -> None:
        """claude 실행파일이 PATH에 있으면 is_available()이 True여야 한다."""
        with patch(
            "news_pulse.blocks.model_engine.claude_cli_engine.shutil.which",
            return_value="/usr/bin/claude",
        ):
            engine = ClaudeCliEngine()
            assert engine.is_available() is True

    def test_is_available_false_when_not_found(self) -> None:
        """claude 실행파일이 없으면 is_available()이 False여야 한다."""
        with patch(
            "news_pulse.blocks.model_engine.claude_cli_engine.shutil.which",
            return_value=None,
        ):
            engine = ClaudeCliEngine()
            assert engine.is_available() is False

    def test_generate_returns_subprocess_output(self) -> None:
        """generate()가 subprocess stdout을 반환해야 한다."""
        mock_result = MagicMock()
        mock_result.stdout = "Claude 응답 텍스트\n"

        with patch(
            "news_pulse.blocks.model_engine.claude_cli_engine.subprocess.run",
            return_value=mock_result,
        ):
            engine = ClaudeCliEngine()
            result = engine.generate("프롬프트", {})

        assert result == "Claude 응답 텍스트"

    def test_load_and_unload_are_noop(self) -> None:
        """load/unload는 no-op으로 예외 없이 실행되어야 한다."""
        engine = ClaudeCliEngine()
        engine.load("any-model")
        engine.unload("any-model")
