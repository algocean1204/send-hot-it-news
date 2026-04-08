"""
FallbackChain 유틸리티.

여러 구현체를 순서대로 시도하고, 첫 번째 성공 결과를 반환한다.
Summarizer, Translator 등에서 공통으로 사용한다.
Generic[_T]으로 선언해 호출 측에서 반환 타입을 구체화할 수 있다.
"""
from __future__ import annotations

import logging
from typing import Generic, TypeVar, cast

logger = logging.getLogger(__name__)

# 반환 타입 제네릭 — 구체 타입은 호출 시 결정된다
_T = TypeVar("_T")


class FallbackChain(Generic[_T]):
    """여러 구현체를 순서대로 시도하고, 첫 성공 결과를 반환한다."""

    def __init__(self, impls: list[object]) -> None:
        """구현체 목록을 주입받는다. 첫 번째부터 순서대로 시도."""
        self._impls = impls

    def execute(self, method_name: str, *args: object, **kwargs: object) -> _T:
        """
        지정된 메서드를 각 구현체에 대해 순서대로 호출한다.

        모든 구현체가 실패하면 마지막 예외를 그대로 올린다.
        각 실패는 WARNING 레벨로 로그에 기록한다.
        """
        last_exc: Exception | None = None
        for impl in self._impls:
            try:
                method = getattr(impl, method_name)
                # cast를 통해 반환값을 _T로 명시 — getattr은 object를 반환하므로 안전하게 변환
                return cast(_T, method(*args, **kwargs))
            except Exception as exc:
                impl_name = type(impl).__name__
                logger.warning("%s 실패, 다음 구현체로 폴백: %s", impl_name, exc)
                last_exc = exc

        # 모든 구현체 실패 — 마지막 예외를 올림
        if last_exc is not None:
            raise last_exc
        raise RuntimeError("구현체 목록이 비어 있어 실행할 수 없습니다.")
