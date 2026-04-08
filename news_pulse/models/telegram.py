"""
텔레그램 관련 dataclass 모듈.

구독자 이벤트(구독/해제)와 메시지 전송 결과를 표현한다.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class SubscriberEvent:
    """구독자 구독/해제 이벤트. SubscriberPoller가 Telegram update에서 생성한다."""

    chat_id: str
    username: str | None
    event_type: str         # "subscribe" | "unsubscribe"
    occurred_at: datetime
    update_id: int          # Telegram update_id (중복 처리 방지용)


@dataclass
class SendResult:
    """TelegramSender가 메시지 전송 후 반환하는 결과."""

    total: int                              # 전체 전송 시도 수
    success_count: int                      # 성공 수
    failed_chat_ids: list[str] = field(default_factory=list)    # 실패한 chat_id 목록
    errors: dict[str, str] = field(default_factory=dict)        # chat_id -> 에러 메시지
