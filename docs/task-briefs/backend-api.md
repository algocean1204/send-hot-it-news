# Task Brief: backend-api

## 프로젝트 개요

news-pulse: 12개 IT/AI 소스에서 뉴스를 수집하고, 로컬 LLM으로 요약/번역 후 텔레그램으로 시간당 1회 푸시하는 macOS 전용 봇.
Python 3.12 + Ollama (GGUF) + SQLite. launchd로 매시 정각 트리거. 상시 프로세스 없음.

---

## 기술 스택

| 항목 | 버전/도구 |
|------|-----------|
| Python | 3.12 |
| 패키지 매니저 | uv (pyproject.toml) |
| HTTP 클라이언트 | httpx (비동기 지원) |
| RSS 파싱 | feedparser |
| 언어 감지 | lingua-language-detector |
| 시스템 모니터링 | psutil |
| 환경변수 | python-dotenv |
| 테스트 | pytest, pytest-asyncio |
| 추론 엔진 | Ollama REST API + Claude CLI subprocess |

---

## 담당 범위

17개 블럭 전체 구현 + 오케스트레이터 조립 + 메인 엔트리포인트.

### 블럭 목록

| # | 블럭 | 한줄 설명 |
|---|------|----------|
| 1 | ConfigLoader | .env -> Config 객체 |
| 2 | MemoryGuard | RAM 체크 -> local_llm / claude_fallback |
| 3 | SubscriberPoller | getUpdates -> 구독자 DB 저장 |
| 4 | Fetcher | 12개 소스 병렬 수집 -> List[RawItem] |
| 5 | Dedup | URL 해시 중복 제거 -> List[NewsItem] |
| 6 | LanguageDetector | 언어 감지 -> lang 필드 추가 |
| 7 | Filter | Tier 분류 + 블랙리스트 -> 최대 8건 |
| 8 | ModelEngine | Ollama/Claude CLI 추론 실행 |
| 9 | Summarizer | 뉴스 요약 (APEX/Kanana/Claude 폴백) |
| 10 | Translator | EN->KO 번역 (Kanana/Claude 폴백) |
| 11 | HotNewsDetector | 핫뉴스 판단 + DB 저장 |
| 12 | MessageFormatter | 텔레그램 MarkdownV2 포맷 |
| 13 | TelegramSender | 메시지 전송 (관리자 + 구독자) |
| 14 | RunLogger | 실행 결과 기록 |
| 15 | ErrorNotifier | 에러 알림 + 로그 |
| 16 | DataCleaner | 30/90일 데이터 정리 |
| 17 | HealthChecker | 시스템 상태 점검 |
| - | Orchestrator | 블럭 조립 + 메인 파이프라인 실행 |

---

## 생성할 파일 구조

```
news_pulse/
├── __init__.py
├── __main__.py                    # 엔트리포인트: python -m news_pulse
├── orchestrator.py                # Pipeline 클래스 (블럭 조립 + 실행)
├── blocks/
│   ├── __init__.py
│   ├── config_loader.py           # 블럭 1
│   ├── memory_guard.py            # 블럭 2
│   ├── subscriber_poller.py       # 블럭 3
│   ├── fetcher/
│   │   ├── __init__.py
│   │   ├── protocol.py            # Fetcher Protocol
│   │   ├── rss_fetcher.py
│   │   ├── algolia_fetcher.py
│   │   ├── reddit_fetcher.py
│   │   └── github_atom_fetcher.py
│   ├── dedup.py                   # 블럭 5
│   ├── language_detector.py       # 블럭 6
│   ├── filter/
│   │   ├── __init__.py
│   │   ├── protocol.py            # Filter Protocol
│   │   ├── blacklist_filter.py
│   │   ├── tier_router.py
│   │   └── priority_selector.py
│   ├── model_engine/
│   │   ├── __init__.py
│   │   ├── protocol.py            # ModelEngine Protocol
│   │   ├── ollama_engine.py
│   │   └── claude_cli_engine.py
│   ├── summarizer/
│   │   ├── __init__.py
│   │   ├── protocol.py            # Summarizer Protocol
│   │   ├── apex_summarizer.py
│   │   ├── kanana_summarizer.py
│   │   └── claude_cli_summarizer.py
│   ├── translator/
│   │   ├── __init__.py
│   │   ├── protocol.py            # Translator Protocol
│   │   ├── kanana_translator.py
│   │   └── claude_cli_translator.py
│   ├── hot_news_detector.py       # 블럭 11
│   ├── message_formatter.py       # 블럭 12
│   ├── telegram_sender.py         # 블럭 13
│   ├── run_logger.py              # 블럭 14
│   ├── error_notifier.py          # 블럭 15
│   ├── data_cleaner.py            # 블럭 16
│   └── health_checker.py          # 블럭 17
├── core/
│   ├── __init__.py
│   └── fallback_chain.py          # FallbackChain 유틸리티
└── tests/
    └── test_blocks/
        ├── __init__.py
        ├── test_config_loader.py
        ├── test_memory_guard.py
        ├── test_fetcher.py
        ├── test_dedup.py
        ├── test_language_detector.py
        ├── test_filter.py
        ├── test_model_engine.py
        ├── test_summarizer.py
        ├── test_translator.py
        ├── test_hot_news_detector.py
        ├── test_message_formatter.py
        ├── test_telegram_sender.py
        └── test_orchestrator.py
```

---

## 블럭 상세 스펙

### 블럭 1 -- ConfigLoader

**파일**: `blocks/config_loader.py`

**Protocol**:
```python
class ConfigLoader(Protocol):
    def load(self) -> Config: ...
```

**IN**: env_path: str -- .env 파일 경로 (기본: 프로젝트 루트)
**OUT**: Config dataclass (news_pulse.models.config.Config)

**내부 로직**:
1. python-dotenv로 .env 파싱
2. 필수 키 검증 (BOT_TOKEN, ADMIN_CHAT_ID, DB_PATH). 누락/빈 문자열 -> ValueError
3. TZ 이중 고정: `os.environ['TZ'] = 'Asia/Seoul'` + `time.tzset()`
4. filter_config 테이블에서 소스 ON/OFF, 필터 임계값 읽기
5. Config dataclass 생성 후 반환

**참조 테이블**: filter_config (key/value 읽기)
**의존 모듈**: 없음 (첫 번째 블럭)
**에러 처리**: 필수 환경 변수 누락 -> ValueError, 파이프라인 즉시 중단

---

### 블럭 2 -- MemoryGuard

**파일**: `blocks/memory_guard.py`

**Protocol**:
```python
class MemoryGuard(Protocol):
    def check(self, config: Config) -> MemoryStatus: ...
```

**IN**: config: Config (memory_threshold_gb 포함)
**OUT**: MemoryStatus -- Literal["local_llm", "claude_fallback"]

**내부 로직**:
1. `psutil.virtual_memory().available`로 가용 메모리 측정
2. 가용 RAM >= config.memory_threshold_gb (기본 26.0GB) -> "local_llm"
3. 가용 RAM < 임계값 -> "claude_fallback"

**에러 처리**: psutil 호출 실패 -> 안전하게 "claude_fallback" 반환

---

### 블럭 3 -- SubscriberPoller

**파일**: `blocks/subscriber_poller.py`

**Protocol**:
```python
class SubscriberPoller(Protocol):
    def poll(self, config: Config) -> list[SubscriberEvent]: ...
```

**IN**: config: Config (bot_token 포함)
**OUT**: list[SubscriberEvent]

**내부 로직**:
1. Telegram Bot API `getUpdates` 호출 (offset으로 이미 처리된 update_id 건너뜀)
2. `/start` 명령어 감지 -> SubscriberEvent(event_type="subscribe") 생성
3. subscribers 테이블에 upsert (SqliteStore.upsert_subscriber)
4. 처리된 최대 update_id + 1을 다음 offset으로 저장

**참조 테이블**: subscribers (INSERT/UPDATE)
**의존 모듈**: ConfigLoader
**에러 처리**: API 호출 실패 -> 빈 리스트 반환, 파이프라인 계속

---

### 블럭 4 -- Fetcher (4개 구현체)

**파일**: `blocks/fetcher/`

**Protocol**:
```python
class Fetcher(Protocol):
    def fetch(self, config: Config) -> list[RawItem]: ...
```

**IN**: config: Config (sources 목록, 타임아웃)
**OUT**: list[RawItem]

#### 구현체

| 구현체 | 파일 | 담당 소스 | 방식 |
|--------|------|----------|------|
| RssFetcher | rss_fetcher.py | GeekNews, Anthropic, OpenAI, DeepMind, HuggingFace, Cursor Changelog | feedparser로 RSS/Atom 파싱 |
| AlgoliaFetcher | algolia_fetcher.py | Hacker News | Algolia API (JSON) `http://hn.algolia.com/api/v1/search` |
| RedditFetcher | reddit_fetcher.py | r/LocalLLaMA, r/ClaudeAI, r/Cursor | `.json` 엔드포인트, 비인증, 커스텀 User-Agent 필수 |
| GithubAtomFetcher | github_atom_fetcher.py | Claude Code Releases, Cline Releases | GitHub Atom 피드 파싱 |

**병렬 수집**: `asyncio.gather()` 또는 `concurrent.futures.ThreadPoolExecutor` 사용.
소스별 독립 실행, 개별 소스 실패 시 해당 소스만 건너뜀.

**RawItem 정규화**: 모든 구현체가 동일한 RawItem 형태로 출력
- url_hash: `hashlib.sha256(url.encode()).hexdigest()`
- fetched_at: `datetime.now()`

**에러 처리**: 개별 소스 실패 -> 해당 소스 건너뜀, 전체 타임아웃 초과 -> 수집된 것만 반환

---

### 블럭 5 -- Dedup (SqliteDedup)

**파일**: `blocks/dedup.py`

**Protocol**:
```python
class Dedup(Protocol):
    def filter_new(self, items: list[RawItem]) -> list[NewsItem]: ...
```

**IN**: items: list[RawItem] (Fetcher 출력)
**OUT**: list[NewsItem] (신규 아이템만, RawItem -> NewsItem 변환 포함)

**내부 로직**:
1. 각 RawItem의 url_hash로 `SqliteStore.url_hash_exists()` 확인
2. 존재하지 않는 항목만 -> NewsItem으로 변환 (lang="" 초기값)
3. 신규 항목을 processed_items 테이블에 즉시 삽입

**참조 테이블**: processed_items (url_hash 조회 + INSERT)
**에러 처리**: DB 접근 실패 -> 전체 아이템을 신규로 간주

---

### 블럭 6 -- LanguageDetector (2개 구현체 체인)

**파일**: `blocks/language_detector.py`

**Protocol**:
```python
class LanguageDetector(Protocol):
    def detect(self, item: NewsItem) -> NewsItem: ...
```

**IN**: item: NewsItem (lang 필드 비어있음)
**OUT**: NewsItem (lang = "ko" | "en")

#### 구현체 체인

| 순서 | 구현체 | 전략 |
|------|--------|------|
| 1 | SourceFirstDetector | 소스 기반: GeekNews -> "ko", 나머지 11개 -> "en" |
| 2 | LinguaDetector | lingua 라이브러리 폴백 (소스 기반 판단 불확실 시만) |

**에러 처리**: lingua 감지 실패 -> "en" 기본값

---

### 블럭 7 -- Filter (3개 구현체 체인)

**파일**: `blocks/filter/`

**Protocol**:
```python
class Filter(Protocol):
    def apply(self, items: list[NewsItem], config: Config) -> list[NewsItem]: ...
```

**IN**: items: list[NewsItem], config: Config (Tier 설정, 블랙리스트)
**OUT**: list[NewsItem] (최대 8건)

#### 구현체 (체인 순서)

| 순서 | 구현체 | 파일 | 역할 |
|------|--------|------|------|
| 1 | BlacklistFilter | blacklist_filter.py | 키워드 블랙리스트 매칭 아이템 제거 |
| 2 | TierRouter | tier_router.py | 소스별 Tier 분류 + 할당량 적용 |
| 3 | PrioritySelector | priority_selector.py | Tier별 우선순위 정렬 -> 최종 8건 선택 |

#### Tier 정책

| Tier | 소스 | 정책 | 할당량 |
|------|------|------|--------|
| 1 | AI랩 블로그 (Anthropic, OpenAI, DeepMind, HuggingFace) + GitHub (Claude Code, Cline, Cursor Changelog) | 무조건 통과 | 7건 |
| 2 | GeekNews | 큐레이션 신뢰, 무조건 통과 | 1건 |
| 3 | Reddit (3개), Hacker News | 업보트 임계값 + 게시 시간 연령 보정 | 4건 |
| 4 (전역) | 전체 | 키워드 블랙리스트 | - |

- Tier 1+2가 8건 초과 시 허용 (allow_tier1_overflow=true)
- 우선순위: Tier 1 -> Tier 2 -> Tier 3 (업보트 높은 순)

**참조 테이블**: filter_config (소스 ON/OFF, 임계값 읽기)
**에러 처리**: 필터 체인 중 예외 -> 해당 필터 건너뜀, 다음 계속

---

### 블럭 8 -- ModelEngine (2개 구현체)

**파일**: `blocks/model_engine/`

**Protocol**:
```python
class ModelEngine(Protocol):
    def load(self, model_name: str, keep_alive: int = 0) -> None: ...
    def generate(self, prompt: str, options: dict) -> str: ...
    def unload(self, model_name: str) -> None: ...
    def is_available(self) -> bool: ...
```

**IN**: model_name: str, prompt: str, options: dict
**OUT**: str (모델 응답 텍스트)

#### 구현체

| 구현체 | 파일 | 방식 |
|--------|------|------|
| OllamaEngine | ollama_engine.py | Ollama REST API. `keep_alive=0`으로 생성 직후 즉시 언로드. load/generate/unload 순서 엄격 |
| ClaudeCliEngine | claude_cli_engine.py | `claude -p --bare` subprocess. load/unload 불필요. is_available()은 `shutil.which('claude')` 확인 |

**순차 로드 원칙**: APEX 사용 완료 후 언로드 확인 -> Kanana 로드. 동시 2모델 메모리 적재 금지.

**Ollama REST API 엔드포인트**:
- POST `http://localhost:11434/api/generate` (추론)
- POST `http://localhost:11434/api/pull` (모델 다운로드)
- DELETE `http://localhost:11434/api/delete` (모델 삭제)
- GET `http://localhost:11434/api/tags` (등록 모델 목록)

**에러 처리**:
- Ollama 연결 실패 -> is_available() False, Summarizer가 폴백 처리
- subprocess 실패 -> CalledProcessError, Summarizer가 처리

---

### 블럭 9 -- Summarizer (3개 구현체, FallbackChain)

**파일**: `blocks/summarizer/`

**Protocol**:
```python
class Summarizer(Protocol):
    def summarize(self, item: NewsItem, engine: ModelEngine) -> SummaryResult: ...
```

**IN**: item: NewsItem, engine: ModelEngine
**OUT**: SummaryResult

#### 구현체 (FallbackChain 순서)

| 순서 | 구현체 | 파일 | 사용 모델 | 특이사항 |
|------|--------|------|----------|---------|
| 1 | ApexSummarizer | apex_summarizer.py | APEX-4B (OllamaEngine) | 한국어/영어 모두 요약. 한국어 소스는 한국어로 직접 요약 |
| 2 | KananaSummarizer | kanana_summarizer.py | kanana-1.5-8b (OllamaEngine) | APEX 폴백 |
| 3 | ClaudeCliSummarizer | claude_cli_summarizer.py | Claude CLI (ClaudeCliEngine) | 최종 폴백 |

각 구현체는 프롬프트 구성 + 응답 파싱만 담당. 실제 추론은 주입받은 ModelEngine에 위임.

**에러 처리**: 요약 실패 -> FallbackChain이 다음 구현체 시도. 전체 실패 -> SummaryResult.error 설정

---

### 블럭 10 -- Translator (2개 구현체, FallbackChain)

**파일**: `blocks/translator/`

**Protocol**:
```python
class Translator(Protocol):
    def translate(self, result: SummaryResult, engine: ModelEngine) -> SummaryResult: ...
```

**IN**: result: SummaryResult (영어 요약), engine: ModelEngine
**OUT**: SummaryResult (한국어 번역 적용)

**조건부 실행**: `item.lang == "ko"`이면 번역 스킵, 원본 그대로 반환.

| 순서 | 구현체 | 파일 | 사용 모델 |
|------|--------|------|----------|
| 1 | KananaTranslator | kanana_translator.py | kanana-1.5-8b (한국어 특화) |
| 2 | ClaudeCliTranslator | claude_cli_translator.py | Claude CLI (폴백) |

**에러 처리**: 번역 실패 -> 영어 요약 원본 유지, error 플래그 표시

---

### 블럭 11 -- HotNewsDetector

**파일**: `blocks/hot_news_detector.py`

**Protocol**:
```python
class HotNewsDetector(Protocol):
    def detect(self, item: NewsItem, result: SummaryResult) -> bool: ...
```

**IN**: item: NewsItem, result: SummaryResult
**OUT**: bool (True면 핫뉴스)

**판단 기준**:

| 방식 | 조건 |
|------|------|
| 업보트 자동 | HN >= 200 OR Reddit >= 80 |
| 소스 자동 | AI랩 공식 발표 (Tier 1) + 핵심 키워드 매칭 |
| 수동 지정 | Flutter 앱에서 관리자가 직접 지정 (이 블럭에서는 처리 안 함) |

핫뉴스로 판단되면:
1. processed_items.is_hot = 1 UPDATE
2. hot_news 테이블에 INSERT (비정규화 데이터 복사)

**참조 테이블**: processed_items (UPDATE), hot_news (INSERT)
**에러 처리**: DB 저장 실패 -> is_hot 판단 결과는 반환, 저장만 재시도

---

### 블럭 12 -- MessageFormatter

**파일**: `blocks/message_formatter.py`

**Protocol**:
```python
class MessageFormatter(Protocol):
    def format(self, item: NewsItem, result: SummaryResult, is_hot: bool) -> str: ...
```

**IN**: item: NewsItem, result: SummaryResult, is_hot: bool
**OUT**: str (텔레그램 MarkdownV2 포맷)

**포맷 정책**:
- 일반 뉴스: 제목 + 한줄 요약 + 링크. 간결 기술체
- 핫뉴스: 제목 + 상세 요약 + 주요 내용 + 링크
- 이모지 + 구분선 + 뉴스 간 2줄 공백
- MarkdownV2 특수문자 이스케이프 필수: `_`, `*`, `[`, `]`, `(`, `)`, `~`, `` ` ``, `>`, `#`, `+`, `-`, `=`, `|`, `{`, `}`, `.`, `!`

**에러 처리**: 포맷 실패 -> 플레인 텍스트 폴백 (이스케이프 없이 제목 + 링크만)

---

### 블럭 13 -- TelegramSender

**파일**: `blocks/telegram_sender.py`

**Protocol**:
```python
class TelegramSender(Protocol):
    def send(self, message: str, chat_ids: list[str]) -> SendResult: ...
```

**IN**: message: str (MarkdownV2), chat_ids: list[str]
**OUT**: SendResult

**내부 로직**:
1. subscribers 테이블에서 approved + admin 대상 chat_id 수집
2. 개별 전송 (Telegram Bot API `sendMessage`)
3. 429 Too Many Requests -> 지수 백오프 retry (최대 3회)

**참조 테이블**: subscribers (approved chat_id 조회)
**에러 처리**: 개별 수신자 실패 -> SendResult에 기록, 나머지 계속. 전체 실패 -> ErrorNotifier

---

### 블럭 14 -- RunLogger

**파일**: `blocks/run_logger.py`

**Protocol**:
```python
class RunLogger(Protocol):
    def log(self, result: PipelineResult) -> None: ...
```

**IN**: result: PipelineResult
**OUT**: None (run_history 테이블에 저장)

**참조 테이블**: run_history (INSERT + UPDATE)
**에러 처리**: DB 저장 실패 -> stderr 로그 폴백

---

### 블럭 15 -- ErrorNotifier

**파일**: `blocks/error_notifier.py`

**Protocol**:
```python
class ErrorNotifier(Protocol):
    def notify(self, exc: Exception, context: dict) -> None: ...
```

**IN**: exc: Exception, context: dict
**OUT**: None (텔레그램 에러 알림 + error_log 저장)

**내부 로직**:
1. 에러 메시지 포맷: `"[news-pulse] module={context['module']} error={str(exc)}"`
2. 관리자 chat_id로 텔레그램 전송
3. error_log 테이블에 INSERT (severity, module, message, traceback)

**참조 테이블**: error_log (INSERT)
**에러 처리**: 알림 전송 실패 -> stderr만 출력, 무한 재귀 방지 (내부 예외 무시)

---

### 블럭 16 -- DataCleaner

**파일**: `blocks/data_cleaner.py`

**Protocol**:
```python
class DataCleaner(Protocol):
    def clean(self, config: Config) -> CleanupResult: ...
```

**IN**: config: Config (테이블별 보관 기간)
**OUT**: CleanupResult (삭제 건수)

**정리 SQL**:
```sql
DELETE FROM processed_items WHERE created_at < datetime('now', '-30 days', 'localtime');
DELETE FROM run_history WHERE started_at < datetime('now', '-90 days', 'localtime');
DELETE FROM error_log WHERE created_at < datetime('now', '-30 days', 'localtime');
DELETE FROM health_check_results WHERE created_at < datetime('now', '-7 days', 'localtime');
```

hot_news는 영구 보관 -- 정리 대상 아님.
VACUUM은 주 1회만 실행 (성능 고려).

**참조 테이블**: processed_items, run_history, error_log, health_check_results (DELETE)
**에러 처리**: 개별 테이블 삭제 실패 -> CleanupResult에 에러 기록, 다음 계속

---

### 블럭 17 -- HealthChecker

**파일**: `blocks/health_checker.py`

**Protocol**:
```python
class HealthChecker(Protocol):
    def check(self, config: Config) -> HealthReport: ...
```

**IN**: config: Config
**OUT**: HealthReport

**점검 항목**:

| 항목 | 점검 내용 |
|------|---------|
| Ollama | REST API 연결 + APEX/Kanana 모델 등록 여부 |
| 소스 URL | 12개 소스 HTTP 응답 확인 |
| Telegram API | Bot API `getMe` 호출 |
| SQLite | PRAGMA integrity_check + 디스크 여유 공간 |

**참조 테이블**: health_check_results (INSERT)
**에러 처리**: 개별 항목 실패 -> HealthReport에 ERROR 기록, 나머지 계속

---

### FallbackChain 유틸리티

**파일**: `core/fallback_chain.py`

```python
class FallbackChain:
    """여러 구현체를 순서대로 시도하고, 첫 성공 결과를 반환한다"""
    def __init__(self, impls: list): ...
    def execute(self, *args, **kwargs) -> Any: ...
```

Summarizer, Translator에서 공통 사용.

---

### Orchestrator (Pipeline 클래스)

**파일**: `orchestrator.py`

```python
class Pipeline:
    def __init__(self, poller, fetchers, dedup, lang_detector, filter_chain,
                 summarizer, translator, hot_detector, formatter, sender,
                 logger, notifier, cleaner, memory_guard, config, db): ...
    def run(self) -> None: ...
```

**메인 파이프라인 흐름**:

```
1. ConfigLoader -> Config
2. MemoryGuard -> MemoryStatus
3. SubscriberPoller -> List[SubscriberEvent]
4. Fetcher (4개 병렬) -> List[RawItem]
5. Dedup -> List[NewsItem] (신규만)
6. LanguageDetector -> List[NewsItem] (lang 추가)
7. Filter -> List[NewsItem] (최대 8건)
8. 신규 0건? -> exit 0
9. ModelEngine APEX 로드
10. Summarizer 전체 요약
11. ModelEngine APEX 언로드, Kanana 로드
12. Translator EN->KO 번역 (영어 소스만)
13. ModelEngine Kanana 언로드
14. HotNewsDetector -> bool
15. MessageFormatter -> str
16. TelegramSender -> SendResult
17. RunLogger -> 실행 결과 기록
18. DataCleaner -> 데이터 정리
19. SQLite 커밋 + exit 0
```

**폴백 체인**: APEX 시도 -> 실패 -> Kanana 단독 -> 실패 -> Claude CLI

**에러 처리**: 전체 파이프라인을 try/except로 감싸고, 예외 시 ErrorNotifier 호출

---

### 엔트리포인트

**파일**: `__main__.py`

```python
"""news-pulse 파이프라인 엔트리포인트. launchd에서 `python -m news_pulse`로 실행"""
```

- ConfigLoader로 Config 로드
- SqliteStore 초기화
- 블럭 생성 + Pipeline 조립
- pipeline.run() 실행
- 헬스체크 CLI 모드: `python -m news_pulse --health-check`

---

## 폴백 체인 상세

```
APEX 시도 -> 실패 -> Kanana 단독 시도 -> 실패 -> Claude CLI
```

발동 조건: RAM < 26GB OR 모델 오류/타임아웃

### 언어별 처리 흐름

- 한국어 소스 (GeekNews): APEX -> 한국어 직접 요약 -> 완료 (번역 불필요)
- 영어 소스 (11개): APEX -> 영어 요약 -> Kanana -> 한국어 번역 -> 완료

---

## 의존성

### pip 패키지

```
httpx
feedparser
python-dotenv
psutil
lingua-language-detector
```

### backend-db에서 import하는 것

- `news_pulse.models.*` -- 모든 dataclass
- `news_pulse.db.store.SqliteStore` -- DB 접근 레이어

### 선행 조건

- **backend-db가 먼저 완료**되어야 함 (models/*, db/store.py)
- models/ 디렉터리와 db/store.py가 존재해야 import 가능

---

## 12개 소스 URL 참조

| source_id | URL / 엔드포인트 | 방식 |
|-----------|-----------------|------|
| geeknews | https://news.hada.io/rss | RSS |
| hackernews | http://hn.algolia.com/api/v1/search | Algolia JSON |
| reddit_localllama | https://www.reddit.com/r/LocalLLaMA/hot.json | Reddit JSON |
| reddit_claudeai | https://www.reddit.com/r/ClaudeAI/hot.json | Reddit JSON |
| reddit_cursor | https://www.reddit.com/r/cursor/hot.json | Reddit JSON |
| anthropic | https://www.anthropic.com/rss.xml | RSS |
| openai | https://openai.com/blog/rss.xml | RSS |
| deepmind | https://deepmind.google/blog/rss.xml | RSS |
| huggingface | https://huggingface.co/blog/feed.xml | RSS/Atom |
| claude_code_releases | https://github.com/anthropics/claude-code/releases.atom | GitHub Atom |
| cline_releases | https://github.com/cline/cline/releases.atom | GitHub Atom |
| cursor_changelog | https://changelog.cursor.com/rss | RSS |

(URL은 구현 시 최신 유효성 확인 필요)

---

## 코딩 규칙

1. 모든 주석/docstring은 한국어로 작성
2. snake_case 함수/변수명
3. 함수당 최대 30줄
4. 파일당 최대 200줄
5. 타입 힌트 필수
6. Protocol 클래스로 인터페이스 정의 (typing.Protocol)
7. 블럭끼리 직접 import 금지 -- 공유 데이터 모델(dataclass)로만 통신
8. 외부 인프라(DB, HTTP) 직접 import 금지 -- DI로 주입
9. `from __future__ import annotations` 사용
10. 상수는 UPPER_SNAKE_CASE

---

## 테스트 요구사항

1. 각 블럭별 단위 테스트 (mock 활용)
2. FallbackChain 동작 테스트 (첫 번째 실패 -> 두 번째 성공)
3. Orchestrator 통합 테스트 (모든 블럭 mock)
4. ConfigLoader: 필수 키 누락 시 ValueError 테스트
5. MemoryGuard: 임계값 경계 테스트
6. Filter: Tier별 할당량 동작 테스트
7. MessageFormatter: MarkdownV2 이스케이프 테스트
8. TelegramSender: 429 retry 테스트

---

## Checkpoint Protocol

각 블럭 완료 후:
1. 이 brief의 해당 블럭 스펙을 다시 읽는다
2. 구현된 OUT이 스펙의 OUT 타입과 일치하는지 검증한다
3. Protocol 인터페이스가 정확히 일치하는지 확인한다
4. 다음 블럭으로 진행한다
5. 이 brief에 없는 블럭/모듈은 절대 구현하지 않는다
