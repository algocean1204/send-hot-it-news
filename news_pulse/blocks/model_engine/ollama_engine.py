"""
OllamaEngine — Ollama REST API 기반 LLM 엔진.

keep_alive=0으로 설정해 생성 직후 모델을 즉시 언로드한다.
순차 모델 로드 원칙: load -> generate -> unload 순서를 반드시 지킨다.
"""
from __future__ import annotations

import logging

import httpx

logger = logging.getLogger(__name__)

# Ollama REST API 엔드포인트
_GENERATE_PATH = "/api/generate"
_TAGS_PATH = "/api/tags"
_PULL_PATH = "/api/pull"

# 추론 기본 타임아웃 (초) — LLM 응답 시간 고려
_GENERATE_TIMEOUT = 300


class OllamaEngine:
    """Ollama REST API를 사용하는 로컬 LLM 엔진."""

    def __init__(self, endpoint: str = "http://localhost:11434") -> None:
        """endpoint: Ollama 서버 기본 URL."""
        self._endpoint = endpoint.rstrip("/")
        self._current_model: str | None = None

    def is_available(self) -> bool:
        """Ollama 서버 연결 가능 여부를 확인한다."""
        try:
            resp = httpx.get(f"{self._endpoint}{_TAGS_PATH}", timeout=5)
            return resp.status_code == 200
        except Exception as exc:
            logger.debug("Ollama 연결 불가: %s", exc)
            return False

    def load(self, model_name: str, keep_alive: int = 0) -> None:
        """
        모델을 Ollama에 로드한다.

        keep_alive=0으로 설정해 generate 완료 후 즉시 언로드되도록 한다.
        실제 로드는 generate 호출 시 자동으로 이뤄진다.
        """
        self._current_model = model_name
        logger.debug("모델 로드 준비 완료: %s (keep_alive=%d)", model_name, keep_alive)

    def generate(self, prompt: str, options: dict[str, object]) -> str:
        """Ollama generate API를 호출해 응답 텍스트를 반환한다."""
        if self._current_model is None:
            raise RuntimeError("generate 호출 전에 load()가 필요합니다.")
        payload = {
            "model": self._current_model,
            "prompt": prompt,
            "stream": False,
            "keep_alive": 0,
            "options": options,
        }
        resp = httpx.post(
            f"{self._endpoint}{_GENERATE_PATH}",
            json=payload,
            timeout=_GENERATE_TIMEOUT,
        )
        resp.raise_for_status()
        data = resp.json()
        # HTTP 200이어도 Ollama가 error 필드를 반환할 수 있다 (모델 미존재, OOM 등)
        if "error" in data:
            raise RuntimeError(f"Ollama 추론 오류: {data['error']}")
        return str(data.get("response", ""))

    def unload(self, model_name: str) -> None:
        """
        모델을 Ollama에서 언로드한다.

        keep_alive=0으로 이미 자동 언로드되지만, 명시적으로 빈 prompt로 호출해 확인한다.
        """
        try:
            # stream:False 필수 — True(기본)이면 응답을 기다리지 않고 바로 반환해 언로드 미확인
            payload = {"model": model_name, "prompt": "", "keep_alive": 0, "stream": False}
            httpx.post(
                f"{self._endpoint}{_GENERATE_PATH}",
                json=payload,
                timeout=30,
            )
        except Exception as exc:
            logger.warning("모델 언로드 중 오류 (무시): %s", exc)
        finally:
            self._current_model = None
            logger.debug("모델 언로드 완료: %s", model_name)

    def unload_all(self) -> None:
        """
        현재 로드된 모델이 있으면 언로드한다.

        SIGTERM 핸들러에서 호출해 프로세스 종료 전 메모리를 해제한다.
        """
        if self._current_model is not None:
            self.unload(self._current_model)
