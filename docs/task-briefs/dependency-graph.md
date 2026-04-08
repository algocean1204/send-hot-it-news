# Dependency Graph

## 실행 순서

```
1. backend-db (스키마 + dataclass + SqliteStore)
       |
       v
2. backend-api (17개 블럭 + 오케스트레이터) -- backend-db 완료 후
       |
       +-----> devops-engineer (병렬 가능) -- 파일 생성은 독립적
       |
       v
3. app-frontend (Flutter 7화면) -- backend-db 스키마 확정 후
       |
       v
4. devops-engineer (최종 검증) -- 모든 엔트리포인트 확정 후
```

### 상세 순서 설명

1. **backend-db** (선행 조건 없음)
   - models/ 전체 dataclass 정의
   - db/schema.sql, db/seed.sql 작성
   - db/store.py (SqliteStore) 구현
   - db/migrate.py 구현
   - 다른 모든 에이전트가 이 산출물에 의존

2. **backend-api** (backend-db 완료 후)
   - models/* 와 db/store.py를 import
   - 17개 블럭 + 오케스트레이터 구현
   - `__main__.py` 엔트리포인트 정의

3. **app-frontend** (backend-db 완료 후, backend-api와 병렬 가능)
   - 테이블 스키마가 확정되면 Flutter 모델/쿼리 작성 가능
   - backend-api와 직접 의존 없음 (SQLite 파일 공유)
   - 헬스체크 subprocess 호출은 인터페이스만 맞추면 됨

4. **devops-engineer** (backend-db/backend-api와 병렬 가능)
   - pyproject.toml, .env.example, .gitignore는 독립적으로 생성 가능
   - launchd plist, install 스크립트는 엔트리포인트 경로만 알면 됨
   - 최종 검증은 모든 에이전트 완료 후

---

## 에이전트 간 계약 (Inter-Agent Contracts)

| 생산자 | 산출물 | 소비자 | 비고 |
|--------|--------|--------|------|
| backend-db | `news_pulse/models/*.py` (전체 dataclass) | backend-api | import하여 사용 |
| backend-db | `news_pulse/db/store.py` (SqliteStore) | backend-api | import하여 사용 |
| backend-db | DB 스키마 (7개 테이블) | app-frontend | 같은 테이블 구조로 Flutter 모델 작성 |
| backend-db | `news_pulse/db/migrate.py` | devops-engineer | setup.sh에서 호출 |
| backend-api | `news_pulse/__main__.py` 엔트리포인트 | devops-engineer | launchd plist에서 실행 |
| backend-api | `--health-check` CLI 플래그 | app-frontend | Flutter에서 subprocess 호출 |
| devops-engineer | `.env.example` | backend-api | ConfigLoader가 읽는 키 목록 |
| devops-engineer | `pyproject.toml` | backend-api | 의존성 패키지 목록 |

---

## 공유 인터페이스 명세

### 1. SQLite DB 파일 경로

```
~/.news-pulse/news_pulse.db
```

- backend-db가 생성
- backend-api가 읽기/쓰기
- app-frontend가 읽기/쓰기
- WAL 모드로 동시 접근 안전

### 2. 공유 dataclass (backend-db가 정의)

```
news_pulse/models/
├── config.py      -> Config, SourceConfig
├── news.py        -> RawItem, NewsItem, SummaryResult
├── pipeline.py    -> PipelineResult, CleanupResult, MemoryStatus
├── telegram.py    -> SubscriberEvent, SendResult
└── health.py      -> HealthStatus, HealthReport
```

### 3. 엔트리포인트 (backend-api가 정의)

```bash
# 일반 실행 (launchd에서 호출)
python -m news_pulse

# 헬스체크 (Flutter에서 subprocess로 호출)
python -m news_pulse --health-check
```

### 4. 환경변수 키 (devops-engineer가 정의)

```
BOT_TOKEN, ADMIN_CHAT_ID, DB_PATH, OLLAMA_ENDPOINT,
APEX_MODEL_NAME, KANANA_MODEL_NAME, MEMORY_THRESHOLD_GB, LOG_PATH
```

---

## 모듈 배정 매트릭스

| 블럭 # | 블럭명 | 담당 에이전트 | 비고 |
|--------|--------|-------------|------|
| - | models/ (전체 dataclass) | backend-db | 공유 인터페이스 |
| - | db/store.py (SqliteStore) | backend-db | DB 접근 레이어 |
| - | db/schema.sql | backend-db | 테이블 DDL |
| - | db/seed.sql | backend-db | 시드 데이터 |
| - | db/migrate.py | backend-db | 마이그레이션 |
| 1 | ConfigLoader | backend-api | |
| 2 | MemoryGuard | backend-api | |
| 3 | SubscriberPoller | backend-api | |
| 4 | Fetcher (4개 구현체) | backend-api | |
| 5 | Dedup (SqliteDedup) | backend-api | |
| 6 | LanguageDetector (2개 구현체) | backend-api | |
| 7 | Filter (3개 구현체) | backend-api | |
| 8 | ModelEngine (2개 구현체) | backend-api | |
| 9 | Summarizer (3개 구현체) | backend-api | |
| 10 | Translator (2개 구현체) | backend-api | |
| 11 | HotNewsDetector | backend-api | |
| 12 | MessageFormatter | backend-api | |
| 13 | TelegramSender | backend-api | |
| 14 | RunLogger | backend-api | |
| 15 | ErrorNotifier | backend-api | |
| 16 | DataCleaner | backend-api | |
| 17 | HealthChecker | backend-api | |
| - | Orchestrator (Pipeline) | backend-api | 블럭 조립 |
| - | __main__.py | backend-api | 엔트리포인트 |
| - | FallbackChain | backend-api | 공용 유틸리티 |
| - | pyproject.toml | devops-engineer | |
| - | .env.example | devops-engineer | |
| - | setup.sh | devops-engineer | Ollama 설정 |
| - | launchd plist | devops-engineer | 스케줄러 |
| - | install/uninstall 스크립트 | devops-engineer | |
| - | .gitignore | devops-engineer | |
| - | Flutter 화면 1: 홈 | app-frontend | 읽기 전용 |
| - | Flutter 화면 2: 날짜별 뉴스 | app-frontend | 읽기+쓰기 |
| - | Flutter 화면 3: 구독자 관리 | app-frontend | 읽기+쓰기 |
| - | Flutter 화면 4: 실행 이력 | app-frontend | 읽기 전용 |
| - | Flutter 화면 5: 오류/헬스체크 | app-frontend | 읽기+subprocess |
| - | Flutter 화면 6: 통계 대시보드 | app-frontend | 읽기 전용 |
| - | Flutter 화면 7: 설정 | app-frontend | 읽기+쓰기 |

---

## 파일 경로 충돌 검증

각 에이전트가 생성하는 파일 경로에 중복 없음:

- **backend-db**: `news_pulse/models/`, `news_pulse/db/`
- **backend-api**: `news_pulse/blocks/`, `news_pulse/core/`, `news_pulse/orchestrator.py`, `news_pulse/__main__.py`, `news_pulse/__init__.py`
- **devops-engineer**: `pyproject.toml`, `.env.example`, `.gitignore`, `scripts/`, `launchd/`
- **app-frontend**: `news_pulse_app/` (별도 디렉터리)

---

## 순환 의존성 검증

```
backend-db -> (없음)
backend-api -> backend-db
app-frontend -> backend-db
devops-engineer -> (없음, 경로 참조만)
```

순환 없음. 단방향 의존성 확인 완료.

---

## ERD 매핑 검증

| 테이블 | backend-db | backend-api | app-frontend |
|--------|-----------|-------------|--------------|
| processed_items | schema + store | Dedup, HotNewsDetector | 화면 1,2,6 |
| hot_news | schema + store | HotNewsDetector | 화면 2 |
| subscribers | schema + store | SubscriberPoller, TelegramSender | 화면 1,3 |
| run_history | schema + store | RunLogger | 화면 1,4,6 |
| error_log | schema + store | ErrorNotifier | 화면 1,5 |
| filter_config | schema + store + seed | ConfigLoader, Filter | 화면 7 |
| health_check_results | schema + store | HealthChecker | 화면 5 |

모든 7개 테이블이 최소 2개 에이전트에서 참조됨. 누락 없음.
