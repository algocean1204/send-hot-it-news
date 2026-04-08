"""
ModelEngine Protocol 정의.

모든 LLM 엔진 구현체는 이 Protocol을 따른다.
순차 모델 로드 원칙: 한 번에 하나의 모델만 메모리에 적재한다.
"""
from __future__ import annotations

from typing import Protocol


class ModelEngine(Protocol):
    """LLM 추론 엔진 인터페이스."""

    def load(self, model_name: str, keep_alive: int = 0) -> None: ...
    def generate(self, prompt: str, options: dict[str, object]) -> str: ...
    def unload(self, model_name: str) -> None: ...
    def is_available(self) -> bool: ...
