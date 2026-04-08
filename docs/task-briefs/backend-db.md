# Task Brief: backend-db

## 프로젝트 개요

news-pulse: 12개 IT/AI 소스에서 뉴스를 수집하고, 로컬 LLM으로 요약/번역 후 텔레그램으로 시간당 1회 푸시하는 macOS 전용 봇.
Python 3.12 백엔드 + Flutter macOS 대시보드가 **SQLite WAL 모드**로 같은 DB 파일을 공유한다.

---

## 기술 스택

| 항목 | 버전/도구 |
|------|-----------|
| Python | 3.12 |
| DB | SQLite 3 (WAL 모드) |
| ORM | 없음 (sqlite3 표준 라이브러리) |
| 패키지 매니저 | uv (pyproject.toml) |
| 테스트 | pytest |

---

## 담당 범위

1. SQLite 7개 테이블 스키마 (CREATE TABLE, INDEX)
2. PRAGMA 초기화 (WAL 모드, FK, busy_timeout)
3. SqliteStore 클래스 (DB 접근 유틸리티)
4. 마이그레이션 스크립트
5. 시드 데이터 삽입
6. 공유 데이터 모델 (dataclass) 전체 정의

---

## 생성할 파일 구조

```
news_pulse/
├── models/
│   ├── __init__.py
│   ├── config.py          # Config, SourceConfig dataclass
│   ├── news.py            # RawItem, NewsItem, SummaryResult
│   ├── pipeline.py        # PipelineResult, CleanupResult, MemoryStatus
│   ├── telegram.py        # SubscriberEvent, SendResult
│   └── health.py          # HealthStatus, HealthReport
├── db/
│   ├── __init__.py
│   ├── store.py           # SqliteStore 클래스
│   ├── schema.sql         # CREATE TABLE + INDEX DDL
│   ├── seed.sql           # 시드 데이터 INSERT
│   └── migrate.py         # 마이그레이션 실행 스크립트
└── tests/
    └── test_db/
        ├── __init__.py
        ├── test_store.py
        └── test_models.py
```

---

## 모듈 상세 스펙

### 1. 공유 데이터 모델 (models/)

모든 블럭 간 통신에 사용되는 dataclass. backend-api와 app-frontend 모두 이 정의에 의존한다.

#### models/config.py

```python
from dataclasses import dataclass, field

@dataclass
class SourceConfig:
    source_id: str        # 예: "geeknews", "hackernews"
    name: str             # 표시명
    url: str              # 피드/API URL
    source_type: str      # "rss" | "algolia" | "reddit" | "github_atom"
    tier: int             # 1 | 2 | 3
    language: str         # "ko" | "en"
    enabled: bool         # ON/OFF

@dataclass
class Config:
    # 텔레그램
    bot_token: str
    admin_chat_id: str

    # DB
    db_path: str

    # 모델
    ollama_endpoint: str          # 기본: "http://localhost:11434"
    apex_model_name: str          # 기본: "apex-i-compact"
    kanana_model_name: str        # 기본: "kanana-2-30b"
    memory_threshold_gb: float    # 기본: 26.0

    # 소스
    sources: list[SourceConfig]   # 12개 소스 설정

    # 필터
    tier1_quota: int              # 기본: 7
    tier2_quota: int              # 기본: 1
    tier3_quota: int              # 기본: 4
    tier3_hn_threshold: int       # HN 업보트 임계값
    tier3_reddit_threshold: int   # Reddit 업보트 임계값
    blacklist_keywords: list[str]

    # 보관 기간
    processed_items_retention_days: int   # 30
    run_history_retention_days: int       # 90
    error_log_retention_days: int         # 30
    health_check_retention_days: int      # 7

    # 핫뉴스
    hot_hn_threshold: int         # 200
    hot_reddit_threshold: int     # 80
```

#### models/news.py

```python
from dataclasses import dataclass
from datetime import datetime

@dataclass
class RawItem:
    url: str
    title: str
    content: str | None
    source_id: str        # 소스 식별자 (예: "hackernews", "geeknews")
    fetched_at: datetime
    upvotes: int | None   # Reddit/HN만
    published_at: datetime | None
    url_hash: str         # SHA256(url)

@dataclass
class NewsItem:
    url: str
    title: str
    content: str | None
    source_id: str
    fetched_at: datetime
    upvotes: int | None
    published_at: datetime | None
    url_hash: str
    lang: str             # "ko" | "en". LanguageDetector가 추가

@dataclass
class SummaryResult:
    item_url: str
    summary_text: str          # 요약 텍스트 (한국어)
    original_lang: str         # 원본 언어 ("ko" | "en")
    summarizer_used: str       # 사용된 Summarizer 구현체명
    translator_used: str | None  # 사용된 Translator 구현체명. 한국어 소스는 None
    error: str | None          # 에러 발생 시 메시지
```

#### models/pipeline.py

```python
from dataclasses import dataclass
from datetime import datetime
from typing import Literal

MemoryStatus = Literal["local_llm", "claude_fallback"]

@dataclass
class PipelineResult:
    run_at: datetime
    fetched_count: int
    dedup_count: int        # 신규 아이템 수
    filtered_count: int     # 필터 통과 수
    summarized_count: int
    sent_count: int
    elapsed_seconds: float
    memory_status: MemoryStatus
    has_error: bool
    error_summary: str | None

@dataclass
class CleanupResult:
    processed_items_deleted: int
    run_history_deleted: int
    error_log_deleted: int
    health_check_deleted: int
    cleaned_at: datetime
```

#### models/telegram.py

```python
from dataclasses import dataclass
from datetime import datetime

@dataclass
class SubscriberEvent:
    chat_id: str
    username: str | None
    event_type: str       # "subscribe" | "unsubscribe"
    occurred_at: datetime
    update_id: int        # Telegram update_id (중복 방지용)

@dataclass
class SendResult:
    total: int
    success_count: int
    failed_chat_ids: list[str]
    errors: dict[str, str]  # chat_id -> 에러 메시지
```

#### models/health.py

```python
from dataclasses import dataclass
from datetime import datetime

@dataclass
class HealthStatus:
    name: str
    status: str       # "OK" | "WARN" | "ERROR"
    message: str

@dataclass
class HealthReport:
    checked_at: datetime
    overall: str      # "OK" | "WARN" | "ERROR"
    items: list[HealthStatus]
```

---

### 2. DB 스키마 (db/schema.sql)

#### PRAGMA 초기화 (모든 테이블 생성 전 실행)

```sql
PRAGMA journal_mode=WAL;          -- WAL 모드 활성화
PRAGMA busy_timeout=5000;         -- 잠금 대기 5초
PRAGMA foreign_keys=ON;           -- FK 제약조건 활성화
PRAGMA synchronous=NORMAL;        -- WAL 모드 권장 동기화 수준
```

#### 마이그레이션 순서 (FK 의존성 기준)

1. filter_config, subscribers (독립 테이블)
2. processed_items (독립, hot_news FK 대상)
3. hot_news (FK: processed_item_id -> processed_items.id)
4. run_history (독립, error_log FK 대상)
5. error_log (FK: run_id -> run_history.id, nullable)
6. health_check_results (독립)

#### 테이블 1: processed_items (30일 보관)

```sql
CREATE TABLE IF NOT EXISTS processed_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    url_hash TEXT UNIQUE NOT NULL,           -- SHA-256 해시 (중복 체크용)
    url TEXT NOT NULL,                        -- 원문 URL
    title TEXT NOT NULL,                      -- 기사 제목
    source TEXT NOT NULL,                     -- 소스명 (geeknews, hackernews 등)
    language TEXT NOT NULL DEFAULT 'en',      -- 언어 코드 (ko/en)
    raw_content TEXT,                         -- 원본 콘텐츠 (선택적)
    summary_ko TEXT,                          -- 한국어 요약 텍스트
    tags TEXT,                                -- 태그 (JSON 배열 문자열, 예: '["AI","LLM"]')
    upvotes INTEGER DEFAULT 0,               -- 업보트 수 (HN/Reddit 전용)
    is_hot INTEGER DEFAULT 0,                -- 핫뉴스 여부 (0=일반, 1=핫)
    pipeline_path TEXT,                       -- 파이프라인 경로 (apex/kanana/claude)
    processing_time_ms INTEGER,              -- 처리 소요시간 (밀리초)
    telegram_sent INTEGER DEFAULT 0,         -- 텔레그램 전송 여부 (0=미전송, 1=전송)
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE INDEX IF NOT EXISTS idx_processed_url_hash ON processed_items(url_hash);
CREATE INDEX IF NOT EXISTS idx_processed_created ON processed_items(created_at);
CREATE INDEX IF NOT EXISTS idx_processed_source ON processed_items(source);
```

#### 테이블 2: hot_news (영구 보관)

```sql
CREATE TABLE IF NOT EXISTS hot_news (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    processed_item_id INTEGER NOT NULL,      -- 원본 뉴스 참조
    url TEXT NOT NULL,                        -- 원문 URL (비정규화, 독립 조회용)
    title TEXT NOT NULL,                      -- 기사 제목
    source TEXT NOT NULL,                     -- 소스명
    summary_ko TEXT NOT NULL,                -- 한국어 요약 (비정규화, 영구 보관)
    tags TEXT,                                -- 태그 (JSON 배열 문자열)
    upvotes INTEGER DEFAULT 0,               -- 업보트 수
    hot_reason TEXT NOT NULL,                 -- 판단 이유 (upvote_auto / source_auto / manual)
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    FOREIGN KEY (processed_item_id) REFERENCES processed_items(id)
);

CREATE INDEX IF NOT EXISTS idx_hot_created ON hot_news(created_at);
```

#### 테이블 3: subscribers (영구 보관)

```sql
CREATE TABLE IF NOT EXISTS subscribers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chat_id INTEGER UNIQUE NOT NULL,         -- 텔레그램 chat_id
    username TEXT,                             -- 텔레그램 username
    first_name TEXT,                           -- 텔레그램 이름
    status TEXT NOT NULL DEFAULT 'pending',   -- 구독 상태 (pending / approved / rejected)
    requested_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    approved_at TEXT,                          -- 승인 시각
    rejected_at TEXT,                          -- 거부 시각
    is_admin INTEGER DEFAULT 0               -- 관리자 여부 (0=일반, 1=관리자)
);

CREATE INDEX IF NOT EXISTS idx_subs_chat_id ON subscribers(chat_id);
CREATE INDEX IF NOT EXISTS idx_subs_status ON subscribers(status);
```

#### 테이블 4: run_history (90일 보관)

```sql
CREATE TABLE IF NOT EXISTS run_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at TEXT NOT NULL,                 -- 실행 시작 시각
    finished_at TEXT,                          -- 실행 종료 시각
    status TEXT NOT NULL DEFAULT 'running',   -- running / success / partial_failure / failure
    fetched_count INTEGER DEFAULT 0,          -- 수집 건수
    filtered_count INTEGER DEFAULT 0,         -- 필터 통과 건수
    summarized_count INTEGER DEFAULT 0,       -- 요약 완료 건수
    sent_count INTEGER DEFAULT 0,             -- 텔레그램 전송 건수
    total_duration_ms INTEGER,               -- 총 소요 시간 (밀리초)
    model_load_ms INTEGER,                   -- 모델 로드 시간 (밀리초)
    inference_ms INTEGER,                    -- 추론 시간 (밀리초)
    memory_mode TEXT,                         -- 메모리 모드 (local_llm / claude_fallback)
    error_message TEXT                        -- 에러 메시지 (실패 시)
);

CREATE INDEX IF NOT EXISTS idx_run_started ON run_history(started_at);
```

#### 테이블 5: error_log (30일 보관)

```sql
CREATE TABLE IF NOT EXISTS error_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,                           -- 실행 참조 (nullable, 실행 외 에러는 NULL)
    severity TEXT NOT NULL DEFAULT 'error',   -- info / warning / error / critical
    module TEXT NOT NULL,                      -- 에러 발생 모듈명
    message TEXT NOT NULL,                     -- 에러 메시지
    traceback TEXT,                            -- Python 스택 트레이스
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    FOREIGN KEY (run_id) REFERENCES run_history(id)
);

CREATE INDEX IF NOT EXISTS idx_error_created ON error_log(created_at);
CREATE INDEX IF NOT EXISTS idx_error_severity ON error_log(severity);
```

#### 테이블 6: filter_config (영구 보관)

```sql
CREATE TABLE IF NOT EXISTS filter_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,                 -- 설정 키 (예: source_geeknews_enabled)
    value TEXT NOT NULL,                       -- 설정 값 (문자열로 저장)
    description TEXT,                          -- 설정 설명 (관리자 참고용)
    updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE INDEX IF NOT EXISTS idx_config_key ON filter_config(key);
```

#### 테이블 7: health_check_results (7일 보관)

```sql
CREATE TABLE IF NOT EXISTS health_check_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    check_type TEXT NOT NULL,                 -- ollama / source / telegram / db / disk
    target TEXT NOT NULL,                      -- 체크 대상 (모델명, 소스 URL 등)
    status TEXT NOT NULL,                      -- ok / warning / error
    message TEXT,                              -- 상태 메시지
    response_time_ms INTEGER,                -- 응답 시간 (밀리초)
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE INDEX IF NOT EXISTS idx_health_created ON health_check_results(created_at);
```

---

### 3. 시드 데이터 (db/seed.sql)

#### filter_config (19건)

| key | value | description |
|-----|-------|-------------|
| source_geeknews_enabled | true | GeekNews RSS 활성화 |
| source_hackernews_enabled | true | Hacker News Algolia API 활성화 |
| source_reddit_localllama_enabled | true | r/LocalLLaMA 활성화 |
| source_reddit_claudeai_enabled | true | r/ClaudeAI 활성화 |
| source_reddit_cursor_enabled | true | r/Cursor 활성화 |
| source_anthropic_enabled | true | Anthropic News RSS 활성화 |
| source_openai_enabled | true | OpenAI News RSS 활성화 |
| source_deepmind_enabled | true | DeepMind Blog RSS 활성화 |
| source_huggingface_enabled | true | HuggingFace Blog RSS 활성화 |
| source_claude_code_enabled | true | Claude Code GitHub Atom 활성화 |
| source_cline_enabled | true | Cline GitHub Atom 활성화 |
| source_cursor_changelog_enabled | true | Cursor Changelog RSS 활성화 |
| hn_min_points | 50 | HN 최소 업보트 (기본 필터) |
| hn_young_min_points | 20 | HN 최소 업보트 (2시간 미만 완화) |
| reddit_localllama_min_upvotes | 25 | r/LocalLLaMA 최소 업보트 |
| reddit_claudeai_min_upvotes | 10 | r/ClaudeAI 최소 업보트 |
| reddit_cursor_min_upvotes | 10 | r/Cursor 최소 업보트 |
| max_items_per_run | 8 | 시간당 최대 전송 건수 |
| allow_tier1_overflow | true | Tier 1+2 초과 시 허용 여부 |

#### subscribers (1건)

```sql
INSERT INTO subscribers (chat_id, username, first_name, status, is_admin)
VALUES (123456789, 'admin_user', 'Admin', 'approved', 1);
```

(chat_id는 실제 관리자 값으로 교체 필요. .env에서 읽어 seed 시 동적 삽입 권장)

---

### 4. SqliteStore 클래스 (db/store.py)

DB 접근 레이어. 모든 블럭이 이 클래스를 통해 DB에 접근한다.

**IN**: db_path (str) -- SQLite 파일 경로
**OUT**: SqliteStore 인스턴스 -- 테이블별 CRUD 메서드 제공

#### 필수 메서드 목록

```python
class SqliteStore:
    def __init__(self, db_path: str) -> None:
        """DB 연결 + PRAGMA 설정. WAL 모드, FK ON, busy_timeout=5000"""

    def close(self) -> None:
        """연결 종료"""

    # --- processed_items ---
    def url_hash_exists(self, url_hash: str) -> bool:
        """URL 해시 존재 여부 (Dedup용)"""

    def insert_processed_item(self, item: dict) -> int:
        """뉴스 아이템 삽입, 삽입된 id 반환"""

    def update_processed_item(self, item_id: int, updates: dict) -> None:
        """뉴스 아이템 부분 업데이트 (summary_ko, is_hot, telegram_sent 등)"""

    def get_processed_items_by_date(self, date_str: str) -> list[dict]:
        """날짜별 뉴스 아이템 조회 (Flutter 화면 2용)"""

    def get_today_sent_count(self) -> int:
        """오늘 전송 건수 (Flutter 화면 1용)"""

    # --- hot_news ---
    def insert_hot_news(self, hot: dict) -> int:
        """핫뉴스 삽입"""

    def delete_hot_news_by_processed_id(self, processed_item_id: int) -> None:
        """핫뉴스 삭제 (수동 토글 해제 시)"""

    def get_hot_news_list(self, limit: int = 50) -> list[dict]:
        """핫뉴스 목록 조회"""

    # --- subscribers ---
    def upsert_subscriber(self, chat_id: int, username: str | None, first_name: str | None) -> None:
        """구독자 INSERT OR UPDATE (중복 chat_id 처리)"""

    def update_subscriber_status(self, chat_id: int, status: str) -> None:
        """구독자 상태 변경 (pending -> approved / rejected)"""

    def get_approved_chat_ids(self) -> list[int]:
        """승인된 구독자 chat_id 목록"""

    def get_subscribers_by_status(self, status: str) -> list[dict]:
        """상태별 구독자 조회"""

    def delete_subscriber(self, chat_id: int) -> None:
        """구독자 삭제"""

    def get_subscriber_counts(self) -> dict[str, int]:
        """상태별 구독자 수 (pending, approved, rejected)"""

    # --- run_history ---
    def insert_run(self, run: dict) -> int:
        """실행 기록 삽입, 삽입된 id 반환"""

    def update_run(self, run_id: int, updates: dict) -> None:
        """실행 기록 업데이트 (종료 시각, 상태, 건수 등)"""

    def get_latest_run(self) -> dict | None:
        """가장 최근 실행 기록"""

    def get_run_history(self, limit: int = 50) -> list[dict]:
        """실행 이력 목록 (시간순 내림차순)"""

    # --- error_log ---
    def insert_error(self, error: dict) -> None:
        """에러 로그 삽입"""

    def get_recent_errors(self, limit: int = 10) -> list[dict]:
        """최근 에러 목록"""

    def get_errors_by_severity(self, severity: str) -> list[dict]:
        """심각도별 에러 조회"""

    # --- filter_config ---
    def get_config_value(self, key: str) -> str | None:
        """설정 값 조회"""

    def set_config_value(self, key: str, value: str) -> None:
        """설정 값 저장 (INSERT OR REPLACE)"""

    def get_all_config(self) -> dict[str, str]:
        """전체 설정 조회 (key -> value 딕셔너리)"""

    # --- health_check_results ---
    def insert_health_check(self, check: dict) -> None:
        """헬스체크 결과 삽입"""

    def get_latest_health_checks(self) -> list[dict]:
        """가장 최근 헬스체크 세트 조회"""

    # --- 정리 ---
    def cleanup_old_data(self, retention_days: dict[str, int]) -> dict[str, int]:
        """보관 기간 지난 데이터 삭제. 삭제 건수 반환"""

    # --- 통계 (Flutter 화면 6용) ---
    def get_source_stats(self, days: int = 7) -> list[dict]:
        """소스별 수집 통계"""

    def get_pipeline_stats(self, days: int = 7) -> list[dict]:
        """파이프라인 경로별 성공률"""
```

#### 구현 주의사항

- `__init__`에서 PRAGMA 4개 반드시 실행
- 모든 메서드는 `sqlite3.Row`를 dict로 변환하여 반환
- `with` 문으로 connection 관리 (context manager 지원)
- 읽기 전용 메서드는 별도 연결 사용 고려 (WAL 모드에서 읽기/쓰기 분리 가능)
- 모든 시간 저장은 `datetime('now','localtime')` 형식 (ISO 8601)

---

### 5. 마이그레이션 스크립트 (db/migrate.py)

```python
def migrate(db_path: str) -> None:
    """스키마 생성 + 시드 데이터 삽입. 멱등성 보장 (IF NOT EXISTS 사용)"""
```

- schema.sql 읽어서 실행
- seed.sql 읽어서 실행 (INSERT OR IGNORE로 중복 방지)
- 실행 후 테이블 수 검증 (7개)
- PRAGMA 확인 (journal_mode=wal, foreign_keys=1)

---

## 데이터 보관 정책 (DataCleaner가 사용할 정보)

| 테이블 | 보관 기간 | 정리 기준 컬럼 | 비고 |
|--------|----------|---------------|------|
| processed_items | 30일 | created_at | is_hot=1이어도 삭제 (hot_news에 복사됨) |
| hot_news | 영구 | - | 삭제 대상 아님 |
| subscribers | 영구 | - | 삭제 대상 아님 |
| run_history | 90일 | started_at | |
| error_log | 30일 | created_at | |
| filter_config | 영구 | - | 삭제 대상 아님 |
| health_check_results | 7일 | created_at | |

정리 SQL:
```sql
DELETE FROM processed_items WHERE created_at < datetime('now', '-30 days', 'localtime');
DELETE FROM run_history WHERE started_at < datetime('now', '-90 days', 'localtime');
DELETE FROM error_log WHERE created_at < datetime('now', '-30 days', 'localtime');
DELETE FROM health_check_results WHERE created_at < datetime('now', '-7 days', 'localtime');
```

---

## 의존성

### pip 패키지
- 없음 (sqlite3는 Python 표준 라이브러리)
- pytest (개발용)

### 다른 에이전트와의 접점
- **backend-api**: SqliteStore와 models/* 전체를 import하여 사용
- **app-frontend**: Flutter에서 같은 DB 파일을 직접 읽기/쓰기 (sqflite 패키지)
- **devops-engineer**: 없음

### 선행 조건
- 없음 (이 에이전트가 가장 먼저 실행됨)

---

## 코딩 규칙

1. 모든 주석/docstring은 한국어로 작성
2. snake_case 함수/변수명
3. 함수당 최대 30줄
4. 파일당 최대 200줄
5. 타입 힌트 필수
6. `from __future__ import annotations` 사용
7. f-string 사용
8. 모든 SQL은 파라미터 바인딩 사용 (? 플레이스홀더, SQL 인젝션 방지)

---

## 테스트 요구사항

1. `test_store.py`: SqliteStore 전체 메서드 테스트 (인메모리 DB `:memory:` 사용)
2. `test_models.py`: dataclass 생성/직렬화 테스트
3. 마이그레이션 멱등성 테스트 (2번 실행해도 에러 없음)
4. FK 제약조건 동작 테스트 (hot_news에 존재하지 않는 processed_item_id 삽입 시 실패)
5. WAL 모드 확인 테스트

---

## Checkpoint Protocol

각 모듈 완료 후:
1. 이 brief의 해당 모듈 스펙을 다시 읽는다
2. 구현된 OUT이 스펙의 OUT 타입과 일치하는지 검증한다
3. 다음 모듈로 진행한다
4. 이 brief에 없는 모듈은 절대 구현하지 않는다
