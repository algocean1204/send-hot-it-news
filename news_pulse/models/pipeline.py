"""
파이프라인 실행 결과 dataclass 모듈.

Orchestrator가 한 번의 파이프라인 실행 결과를 PipelineResult로 기록하며,
DataCleaner가 정리 결과를 CleanupResult로 반환한다.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Literal

# 메모리 상태 — 로컬 LLM 사용 가능 여부에 따라 분기
MemoryStatus = Literal["local_llm", "claude_fallback"]


@dataclass
class PipelineResult:
    """한 번의 파이프라인 실행 결과. RunLogger가 run_history 테이블에 저장한다."""

    run_at: datetime
    fetched_count: int          # 수집 건수
    dedup_count: int            # 중복 제거 후 신규 아이템 수
    filtered_count: int         # 필터 통과 수
    summarized_count: int       # 요약 완료 수
    sent_count: int             # 텔레그램 전송 수
    elapsed_seconds: float      # 총 소요 시간 (초)
    memory_status: MemoryStatus # 메모리 상태 (로컬 LLM / 클로드 폴백)
    has_error: bool             # 에러 발생 여부
    error_summary: str | None   # 에러 요약 메시지
    fetch_errors: int = 0       # 수집기 개별 실패 횟수 (파이프라인 전체 실패와 구분)


@dataclass
class CleanupResult:
    """DataCleaner 실행 결과. 보관 기간이 지난 데이터 삭제 건수를 담는다."""

    processed_items_deleted: int    # 삭제된 뉴스 아이템 수
    run_history_deleted: int        # 삭제된 실행 기록 수
    error_log_deleted: int          # 삭제된 에러 로그 수
    health_check_deleted: int       # 삭제된 헬스체크 결과 수
    cleaned_at: datetime            # 정리 실행 시각
