"""
OllamaEngine 확장 테스트.

unload 동작, unload 실패 시 무시, unload 후 current_model 초기화를 검증한다.
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from news_pulse.blocks.model_engine.ollama_engine import OllamaEngine


def test_unload_정상_동작() -> None:
    """unload 호출 시 빈 프롬프트로 POST 요청을 보내야 한다."""
    engine = OllamaEngine("http://localhost:11434")
    engine.load("apex-model")

    with patch("news_pulse.blocks.model_engine.ollama_engine.httpx.post") as mock_post:
        mock_post.return_value = MagicMock(status_code=200)
        engine.unload("apex-model")

    mock_post.assert_called_once()
    payload = mock_post.call_args[1]["json"]
    assert payload["model"] == "apex-model"
    assert payload["keep_alive"] == 0


def test_unload_후_current_model_초기화() -> None:
    """unload 후 _current_model이 None이어야 한다."""
    engine = OllamaEngine()
    engine.load("test-model")
    assert engine._current_model == "test-model"

    with patch("news_pulse.blocks.model_engine.ollama_engine.httpx.post"):
        engine.unload("test-model")

    assert engine._current_model is None


def test_unload_실패시_예외_무시() -> None:
    """unload 중 예외가 발생해도 무시하고 current_model을 초기화해야 한다."""
    engine = OllamaEngine()
    engine.load("test-model")

    with patch(
        "news_pulse.blocks.model_engine.ollama_engine.httpx.post",
        side_effect=ConnectionError("서버 연결 불가"),
    ):
        engine.unload("test-model")  # 예외 없이 완료되어야 한다

    assert engine._current_model is None


def test_generate_후_응답_파싱() -> None:
    """generate 결과에서 response 키를 추출해야 한다."""
    engine = OllamaEngine()
    engine.load("test-model")

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"response": "  요약 결과  ", "done": True}

    with patch(
        "news_pulse.blocks.model_engine.ollama_engine.httpx.post",
        return_value=mock_resp,
    ):
        result = engine.generate("프롬프트", {"temperature": 0.3})

    assert result == "  요약 결과  "


def test_generate_응답에_response_키_없을때_빈문자열() -> None:
    """응답 JSON에 response 키가 없으면 빈 문자열을 반환해야 한다."""
    engine = OllamaEngine()
    engine.load("test-model")

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"done": True}

    with patch(
        "news_pulse.blocks.model_engine.ollama_engine.httpx.post",
        return_value=mock_resp,
    ):
        result = engine.generate("프롬프트", {})

    assert result == ""
