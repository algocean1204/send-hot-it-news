# Feature Spec v2 — news-pulse 14개 신규 기능 설계서

---

## 목차

1. [프로젝트 현황 요약](#1-프로젝트-현황-요약)
2. [DB 마이그레이션 통합 계획](#2-db-마이그레이션-통합-계획)
3. [기능별 상세 설계](#3-기능별-상세-설계)
4. [의존 관계 및 구현 순서](#4-의존-관계-및-구현-순서)
5. [seed 데이터 추가 계획](#5-seed-데이터-추가-계획)
6. [에이전트별 작업 배정](#6-에이전트별-작업-배정)
7. [주의사항](#7-주의사항)

---

## 1. 프로젝트 현황 요약

| 항목 | 현재 상태 |
|------|-----------|
| Python 블럭 | 17개 (13 파이프라인 + 4 인프라) |
| DB 테이블 | 7개 (filter_config, subscribers, processed_items, hot_news, run_history, error_log, health_check_results) |
| Flutter 화면 | 7개 (home, news, subscribers, history, errors, stats, settings) |
| Flutter Repository | 6개 (config, error, health, news, run, subscriber) |
| Flutter Provider | 7개 (config, database, error, health, news, run, subscriber) |
| Flutter Model | 7개 (error_log, filter_config, health_check_result, hot_news, processed_item, run_history, subscriber) |
| 파이프라인 구조 | fetch -> dedup -> lang_detect -> filter(blacklist->tier->priority) -> summarize -> translate -> hot_detect -> format -> send |
| 설정 관리 | .env (필수 환경변수) + filter_config 테이블 (런타임 설정) |

### 패턴 참조

- **Python 블럭 패턴**: Protocol 정의 + 구현체 클래스. `__init__`에서 DI, 예외 시 warning 로그 후 폴백
- **Python 파이프라인 패턴**: `core/` 아래 원자 모듈 함수로 분리, orchestrator가 조합
- **Python DB 패턴**: `store.py`가 위임, `store_*.py`가 실제 SQL 실행. `_Row = dict[str, _SqliteVal]` 타입 사용
- **Flutter Repository 패턴**: `Database`를 생성자 DI, rawQuery/rawUpdate 사용, `fromMap` 팩토리
- **Flutter Provider 패턴**: `FutureProvider.autoDispose`로 선언, `ref.watch(databaseProvider)` 체이닝
- **Flutter 화면 패턴**: `ConsumerWidget`, `_buildHeader` + `_buildSection` 패턴, `AppColors` 참조

---

## 2. DB 마이그레이션 통합 계획

### 2.1 새 테이블 (4개)

```sql
-- ============================================================
-- 테이블 8: whitelist_keywords (영구 보관)
-- 관심 키워드 목록. Tier3 아이템이 키워드 매칭 시 업보트 무시하고 통과한다.
-- Flutter 설정 화면에서 관리, TierRouter가 읽는다.
-- ============================================================
CREATE TABLE IF NOT EXISTS whitelist_keywords (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    keyword TEXT UNIQUE NOT NULL,              -- 관심 키워드 (소문자 저장)
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE INDEX IF NOT EXISTS idx_whitelist_keyword ON whitelist_keywords(keyword);

-- ============================================================
-- 테이블 9: model_usage_log (90일 보관)
-- 모델별 추론 소요시간 기록. 지연 추이 차트 및 모델 추적에 사용한다.
-- Summarizer/Translator가 쓰고, Flutter 통계 화면이 읽는다.
-- ============================================================
CREATE TABLE IF NOT EXISTS model_usage_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER,                            -- run_history 참조 (nullable)
    processed_item_id INTEGER,                 -- processed_items 참조 (nullable)
    model_name TEXT NOT NULL,                  -- 모델명 (apex-i-compact, kanana-2-30b, claude-cli)
    task_type TEXT NOT NULL,                   -- 'summarize' | 'translate'
    latency_ms INTEGER NOT NULL,               -- 추론 소요시간 (밀리초)
    input_tokens INTEGER,                      -- 입력 토큰 수 (추정값, nullable)
    success INTEGER NOT NULL DEFAULT 1,        -- 성공 여부 (0=실패, 1=성공)
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    FOREIGN KEY (run_id) REFERENCES run_history(id) ON DELETE SET NULL,
    FOREIGN KEY (processed_item_id) REFERENCES processed_items(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_model_usage_created ON model_usage_log(created_at);
CREATE INDEX IF NOT EXISTS idx_model_usage_model ON model_usage_log(model_name);

-- ============================================================
-- 테이블 10: prompt_versions (영구 보관)
-- 프롬프트 버전 관리. 어떤 프롬프트 버전이 어떤 요약을 생성했는지 추적한다.
-- Flutter 설정 화면에서 관리한다.
-- ============================================================
CREATE TABLE IF NOT EXISTS prompt_versions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    prompt_type TEXT NOT NULL,                  -- 'summarize_ko' | 'summarize_en' | 'translate'
    version INTEGER NOT NULL,                  -- 버전 번호 (자동 증가)
    content TEXT NOT NULL,                     -- 프롬프트 전문
    is_active INTEGER NOT NULL DEFAULT 0,      -- 현재 활성 버전 (0=비활성, 1=활성)
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    UNIQUE(prompt_type, version)
);

CREATE INDEX IF NOT EXISTS idx_prompt_type_active ON prompt_versions(prompt_type, is_active);

-- ============================================================
-- 테이블 11: schedule_log (30일 보관)
-- launchd 실행 스케줄 추적. 놓친 실행 감지에 사용한다.
-- ============================================================
CREATE TABLE IF NOT EXISTS schedule_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scheduled_at TEXT NOT NULL,                 -- 예정 실행 시각
    actual_at TEXT,                             -- 실제 실행 시각 (놓친 경우 NULL)
    status TEXT NOT NULL DEFAULT 'pending',     -- 'pending' | 'executed' | 'missed' | 'catchup'
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE INDEX IF NOT EXISTS idx_schedule_status ON schedule_log(status);
CREATE INDEX IF NOT EXISTS idx_schedule_scheduled ON schedule_log(scheduled_at);
```

### 2.2 기존 테이블 변경

```sql
-- processed_items 테이블에 컬럼 추가
ALTER TABLE processed_items ADD COLUMN is_read INTEGER NOT NULL DEFAULT 0;
-- 읽음 여부 (0=미읽음, 1=읽음). Flutter 앱에서 상세 보기 시 1로 변경

ALTER TABLE processed_items ADD COLUMN summarizer_model TEXT;
-- 요약에 사용된 모델명 (apex-i-compact, kanana-2-30b, claude-cli)

ALTER TABLE processed_items ADD COLUMN translator_model TEXT;
-- 번역에 사용된 모델명

ALTER TABLE processed_items ADD COLUMN prompt_version_id INTEGER;
-- 사용된 프롬프트 버전 ID (prompt_versions.id 참조)

-- 읽음 상태 조회 인덱스
CREATE INDEX IF NOT EXISTS idx_processed_is_read ON processed_items(is_read);
```

### 2.3 마이그레이션 전략

기존 `migrate.py`의 `_EXPECTED_TABLE_COUNT`를 7 -> 11로 변경한다.
`schema.sql`에 새 테이블 4개를 추가하고, ALTER TABLE 구문은 별도 마이그레이션 함수 `_apply_alter_tables`로 분리한다.
ALTER TABLE은 IF NOT EXISTS를 지원하지 않으므로, 컬럼 존재 여부를 `PRAGMA table_info`로 확인 후 조건부 실행한다.

---

## 3. 기능별 상세 설계

---

### F01. Keyword Whitelist (P1) — 복잡도: M

**설명**: 사용자가 Flutter 설정 화면에서 관심 키워드를 등록하면, Tier 3 아이템(Reddit/HN)의 제목/본문에 해당 키워드가 포함될 경우 업보트 수에 관계없이 필터를 자동 통과시킨다.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| Python 신규 | `news_pulse/blocks/filter/whitelist_filter.py` | WhitelistFilter 블럭 — DB에서 키워드 조회 후 Tier3 아이템 매칭 |
| Python 수정 | `news_pulse/blocks/filter/tier_router.py` | `_passes_tier3`에서 WhitelistFilter 결과를 OR 조건으로 추가 |
| Python 수정 | `news_pulse/orchestrator.py` | WhitelistFilter 인스턴스 생성 및 TierRouter에 주입 |
| Python 수정 | `news_pulse/db/store.py` | `get_whitelist_keywords()` 메서드 추가 |
| Python 신규 | `news_pulse/db/store_whitelist.py` | whitelist_keywords CRUD SQL |
| DB 신규 | `news_pulse/db/schema.sql` | whitelist_keywords 테이블 |
| Flutter 신규 | `news_pulse_app/lib/repositories/whitelist_repository.dart` | CRUD 메서드 |
| Flutter 신규 | `news_pulse_app/lib/models/whitelist_keyword.dart` | 데이터 모델 |
| Flutter 신규 | `news_pulse_app/lib/providers/whitelist_provider.dart` | 상태 관리 |
| Flutter 수정 | `news_pulse_app/lib/screens/settings/settings_screen.dart` | 키워드 관리 섹션 추가 |
| Flutter 신규 | `news_pulse_app/lib/screens/settings/widgets/keyword_chip_input.dart` | Chip 기반 키워드 입력 위젯 |
| Flutter 수정 | `news_pulse_app/lib/core/database/tables.dart` | WhitelistKeywordsCol 추가 |

**DB 변경**: whitelist_keywords 테이블 신규 생성 (2.1 참조)

**구현 접근**:
- `WhitelistFilter`는 독립 블럭이 아니라 TierRouter 내부에서 사용하는 보조 모듈로 구현한다. TierRouter의 `_passes_tier3` 메서드에서 기존 업보트 체크가 실패해도 화이트리스트 키워드 매칭이면 True를 반환한다.
- DB에서 키워드를 매 실행마다 한 번 로드해 메모리에 캐시한다 (파이프라인 1회 실행 내에서만 유효).
- 키워드 매칭은 대소문자 무시, 부분 문자열 매칭 (기존 BlacklistFilter와 동일 방식).

**Flutter UI**:
- 설정 화면에 "관심 키워드" 섹션 추가
- Chip 형태로 키워드를 표시/추가/삭제
- TextField + Add 버튼으로 새 키워드 등록
- 소문자 정규화 후 저장

---

### F02. Manual Trigger (P1) — 복잡도: L

**설명**: Flutter 앱에서 버튼 하나로 Python 파이프라인을 즉시 실행한다. 진행 상태와 결과를 앱에 실시간 표시한다.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| Python 수정 | `news_pulse/__main__.py` | `--manual-trigger` 인수 추가, 결과를 JSON stdout 출력 |
| Flutter 신규 | `news_pulse_app/lib/services/pipeline_runner.dart` | `Process.start` 래퍼 — Python subprocess 실행/모니터링 |
| Flutter 신규 | `news_pulse_app/lib/providers/manual_trigger_provider.dart` | 트리거 상태(idle/running/done/error) 관리 |
| Flutter 수정 | `news_pulse_app/lib/screens/home/home_screen.dart` | "지금 실행" 버튼 추가 |
| Flutter 신규 | `news_pulse_app/lib/screens/home/widgets/manual_trigger_button.dart` | 실행 버튼 + 진행 인디케이터 위젯 |
| Flutter 신규 | `news_pulse_app/lib/screens/home/widgets/trigger_result_dialog.dart` | 실행 결과 다이얼로그 |

**DB 변경**: 없음 (run_history에 기존 방식대로 기록됨)

**구현 접근**:
- Flutter에서 `Process.start('uv', ['run', 'python', '-m', 'news_pulse', '--manual-trigger'])`로 실행한다.
- `--manual-trigger` 모드는 `run_pipeline()`과 동일하되, 진행 상태를 stderr로 JSON Line 형식으로 출력한다: `{"stage": "fetch", "count": 42}`, `{"stage": "filter", "count": 12}` 등.
- 최종 결과도 JSON stdout으로 출력 (기존 `--health-check` 패턴과 동일).
- Flutter에서 stderr stream을 읽어 실시간 진행 표시, stdout에서 최종 결과를 파싱한다.
- 이미 실행 중인 경우 중복 실행을 방지한다 (PID 파일 또는 lock 파일 체크).
- `__main__.py`의 기존 `argparse` 패턴을 따라 `--manual-trigger` 서브커맨드를 추가한다.

**Flutter UI**:
- 홈 화면 헤더 오른쪽에 "지금 실행" 버튼 (기존 새로고침 버튼 왼쪽)
- 실행 중: 버튼 비활성화 + CircularProgressIndicator + 현재 단계 텍스트
- 완료 시: 결과 다이얼로그 (수집/필터/요약/전송 건수)

**의존**: 없음 (독립)

---

### F03. Read Status Tracking (P1) — 복잡도: S

**설명**: 뉴스 아이템의 읽음/안읽음 상태를 추적한다. Flutter에서 상세 보기 시 읽음 처리. 홈 화면에 안읽은 건수 표시.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| DB 수정 | `news_pulse/db/schema.sql` | processed_items에 `is_read` 컬럼 추가 |
| Python 수정 | `news_pulse/db/store_processed.py` | `_PROCESSED_ITEM_COLUMNS`에 `is_read` 추가 |
| Flutter 수정 | `news_pulse_app/lib/models/processed_item.dart` | `isRead` 필드 추가, `fromMap` 수정 |
| Flutter 수정 | `news_pulse_app/lib/repositories/news_repository.dart` | `markAsRead()`, `getUnreadCount()` 메서드 추가 |
| Flutter 수정 | `news_pulse_app/lib/providers/news_provider.dart` | `unreadCountProvider` 추가 |
| Flutter 수정 | `news_pulse_app/lib/screens/news/news_screen.dart` | 읽은 아이템 시각 차별화 (불투명도 조절) |
| Flutter 수정 | `news_pulse_app/lib/screens/news/widgets/news_list_tile.dart` | 읽음 인디케이터(파란 점) 추가 |
| Flutter 수정 | `news_pulse_app/lib/screens/news/widgets/news_detail_dialog.dart` | 열릴 때 `markAsRead()` 호출 |
| Flutter 수정 | `news_pulse_app/lib/screens/home/home_screen.dart` | 안읽은 뉴스 카운트 카드 추가 |
| Flutter 신규 | `news_pulse_app/lib/screens/home/widgets/unread_count_card.dart` | 안읽은 뉴스 카드 위젯 |
| Flutter 수정 | `news_pulse_app/lib/core/database/tables.dart` | `ProcessedItemsCol.isRead` 추가 |

**DB 변경**: processed_items에 `is_read INTEGER NOT NULL DEFAULT 0` 컬럼 추가

**구현 접근**:
- `NewsDetailDialog` 위젯이 빌드될 때(= 사용자가 뉴스 상세를 열 때) `markAsRead(item.id)`를 호출한다.
- `NewsListTile`에서 `isRead`가 false인 항목에 왼쪽 파란 점 인디케이터를 표시한다.
- `getUnreadCount()`는 `SELECT COUNT(*) FROM processed_items WHERE is_read=0 AND telegram_sent=1`로 구현한다.
- 홈 화면에 기존 `TodayCountCard` 옆에 `UnreadCountCard`를 추가한다.

---

### F04. Model Traceability (P1) — 복잡도: M

**설명**: 각 뉴스 아이템의 요약/번역에 어떤 모델(APEX/Kanana/Claude CLI)이 사용되었는지 기록하고, Flutter 상세 보기에 표시한다.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| DB 수정 | `news_pulse/db/schema.sql` | processed_items에 `summarizer_model`, `translator_model` 컬럼 추가 |
| Python 수정 | `news_pulse/db/store_processed.py` | `_PROCESSED_ITEM_COLUMNS`에 `summarizer_model`, `translator_model` 추가 |
| Python 수정 | `news_pulse/core/summarize_pipeline.py` | 요약/번역 완료 후 모델명을 DB에 저장 |
| Python 수정 | `news_pulse/blocks/dedup.py` | `_insert_to_db`에 `summarizer_model`, `translator_model` 초기값 추가 |
| Flutter 수정 | `news_pulse_app/lib/models/processed_item.dart` | `summarizerModel`, `translatorModel` 필드 추가 |
| Flutter 수정 | `news_pulse_app/lib/screens/news/widgets/news_detail_content.dart` | 모델 정보 표시 섹션 추가 |
| Flutter 수정 | `news_pulse_app/lib/core/database/tables.dart` | `ProcessedItemsCol.summarizerModel`, `.translatorModel` 추가 |

**DB 변경**: processed_items에 `summarizer_model TEXT`, `translator_model TEXT` 컬럼 추가

**구현 접근**:
- 기존 `SummaryResult.summarizer_used`와 `SummaryResult.translator_used` 필드에 이미 모델 구현체명이 기록된다 (예: "ApexSummarizer", "KananaTranslator").
- `summarize_pipeline.py`에서 요약/번역 완료 후 `store.update_processed_item()`으로 모델명을 저장한다.
- 모델명은 구현체 클래스명이 아닌 실제 모델명("apex-i-compact", "kanana-2-30b", "claude-cli")으로 저장한다. 각 Summarizer/Translator에 `model_display_name` 속성을 추가한다.
- Flutter 상세 보기에서 "요약: APEX-4B / 번역: Kanana-2-30B" 형태로 표시한다.

---

### F05. Skip Detection (P1) — 복잡도: M

**설명**: launchd가 수면/종료로 실행을 놓쳤을 때 감지하고, 다음 기상 시 놓친 시간대의 캐치업 실행을 제안한다.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| DB 신규 | `news_pulse/db/schema.sql` | schedule_log 테이블 |
| Python 신규 | `news_pulse/blocks/skip_detector.py` | 스케줄 비교 로직 — 예정 시각 vs 실제 실행 시각 비교 |
| Python 신규 | `news_pulse/db/store_schedule.py` | schedule_log CRUD SQL |
| Python 수정 | `news_pulse/db/store.py` | schedule 관련 위임 메서드 추가 |
| Python 수정 | `news_pulse/orchestrator.py` | 파이프라인 시작 시 skip_detector 호출 |
| Python 수정 | `news_pulse/__main__.py` | `--catchup` 인수 추가 (놓친 시간대 일괄 실행) |
| Flutter 수정 | `news_pulse_app/lib/screens/home/home_screen.dart` | 놓친 실행 경고 배지 표시 |
| Flutter 신규 | `news_pulse_app/lib/screens/home/widgets/missed_run_banner.dart` | 놓친 실행 배너 위젯 |
| Flutter 신규 | `news_pulse_app/lib/repositories/schedule_repository.dart` | schedule_log 조회 |
| Flutter 신규 | `news_pulse_app/lib/models/schedule_log.dart` | 데이터 모델 |
| Flutter 신규 | `news_pulse_app/lib/providers/schedule_provider.dart` | 놓친 실행 감지 상태 |
| Flutter 수정 | `news_pulse_app/lib/core/database/tables.dart` | ScheduleLogCol 추가 |

**DB 변경**: schedule_log 테이블 신규 생성 (2.1 참조)

**구현 접근**:
- 파이프라인 시작 시 SkipDetector가 현재 시각과 마지막 실행 시각을 비교한다.
- launchd 스케줄 (09:00~00:00 매시)을 기준으로 사이에 놓친 시간대를 계산한다.
- 놓친 시간대가 있으면 schedule_log에 status='missed'로 기록한다.
- `--catchup` 모드에서는 놓친 시간대만큼 파이프라인을 반복 실행한다 (각 실행은 독립적).
- Flutter 홈 화면 상단에 "N건의 실행이 누락되었습니다" 배너를 표시하고, Manual Trigger(F02)와 연동해 캐치업 실행을 제안한다.

**의존**: F02 (Manual Trigger)와 연동하면 캐치업 실행 가능. 독립 구현은 가능하나, 캐치업 실행 UI는 F02 이후.

---

### F06. Latency Trending (P2) — 복잡도: M

**설명**: 모델별(APEX/Kanana/Claude) 추론 소요시간을 시계열 차트로 통계 화면에 표시한다.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| DB 신규 | `news_pulse/db/schema.sql` | model_usage_log 테이블 |
| Python 신규 | `news_pulse/blocks/model_usage_tracker.py` | 모델 사용 기록 블럭 |
| Python 신규 | `news_pulse/db/store_model_usage.py` | model_usage_log CRUD SQL |
| Python 수정 | `news_pulse/db/store.py` | model_usage 관련 위임 메서드 추가 |
| Python 수정 | `news_pulse/core/summarize_pipeline.py` | 요약/번역 전후로 타이밍 측정 및 기록 |
| Flutter 신규 | `news_pulse_app/lib/repositories/model_usage_repository.dart` | 모델별 지연시간 조회 |
| Flutter 신규 | `news_pulse_app/lib/models/model_usage.dart` | 데이터 모델 |
| Flutter 신규 | `news_pulse_app/lib/providers/model_usage_provider.dart` | 차트 데이터 상태 |
| Flutter 수정 | `news_pulse_app/lib/screens/stats/stats_screen.dart` | 모델 지연시간 차트 섹션 추가 |
| Flutter 신규 | `news_pulse_app/lib/screens/stats/widgets/latency_chart.dart` | 모델별 지연시간 라인 차트 위젯 |
| Flutter 수정 | `news_pulse_app/lib/core/database/tables.dart` | ModelUsageLogCol 추가 |

**DB 변경**: model_usage_log 테이블 신규 생성 (2.1 참조)

**구현 접근**:
- `summarize_pipeline.py`의 `_run_summarize`와 번역 루프에서 각 아이템 처리 전후에 `time.monotonic()`으로 소요시간을 측정한다.
- `ModelUsageTracker` 블럭이 `model_usage_log`에 INSERT한다.
- Flutter 통계 화면에 fl_chart 라인 차트를 추가한다. X축=날짜, Y축=평균 latency_ms, 모델별 색상 구분.
- 데이터 집계: `SELECT model_name, date(created_at) as d, AVG(latency_ms) as avg_ms FROM model_usage_log GROUP BY model_name, d ORDER BY d`.

**의존**: F04 (Model Traceability)와 모델명 기록 공유 — F04 없이도 구현 가능하나, 동시 구현이 효율적.

---

### F07. Digest Mode (P2) — 복잡도: L

**설명**: 개별 푸시 대신 하루치 뉴스를 한 번에 묶어 설정된 시간(예: 09:00)에 요약 Telegram 메시지로 발송한다. 기존 개별 모드와 토글로 선택 가능.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| Python 신규 | `news_pulse/blocks/digest_formatter.py` | 다이제스트 메시지 포맷터 (여러 아이템을 하나의 메시지로 묶음) |
| Python 신규 | `news_pulse/core/digest_pipeline.py` | 다이제스트 전용 파이프라인 원자 모듈 |
| Python 수정 | `news_pulse/orchestrator.py` | digest_mode 분기 추가 |
| Python 수정 | `news_pulse/__main__.py` | `--digest` 인수 추가 |
| Python 수정 | `news_pulse/blocks/config_loader.py` | digest 관련 config 로딩 |
| Python 수정 | `news_pulse/models/config.py` | `digest_enabled`, `digest_hour` 필드 추가 |
| DB seed | `news_pulse/db/seed.sql` | `digest_enabled`, `digest_hour` 시드 데이터 |
| Flutter 수정 | `news_pulse_app/lib/screens/settings/settings_screen.dart` | 다이제스트 모드 섹션 추가 |
| Flutter 신규 | `news_pulse_app/lib/screens/settings/widgets/digest_settings.dart` | 시간 선택 + 활성화 토글 |

**DB 변경**: filter_config에 `digest_enabled`, `digest_hour` 키 추가 (seed 데이터)

**구현 접근**:
- **개별 모드** (기본): 현재와 동일. 매 시간 실행 시 즉시 전송.
- **다이제스트 모드**: 매 시간 실행은 수집/필터/요약만 하고 `telegram_sent=0`으로 유지. 설정된 시간(예: 09:00)에만 `telegram_sent=0`인 모든 아이템을 하나의 다이제스트 메시지로 묶어 전송.
- 다이제스트 메시지 포맷: 핫뉴스 먼저, 일반뉴스 후. 각 아이템은 "제목 + 한줄 요약 + 링크" 형태.
- Telegram 메시지 4096자 제한 대응: 초과 시 여러 메시지로 분할.
- launchd 스케줄 자체는 변경하지 않는다. 다이제스트 시간에만 전송 로직을 실행한다.

**의존**: 없음 (독립)

---

### F08. Blacklist Suggestion (P2) — 복잡도: M

**설명**: 자주 필터링되는 키워드/도메인을 분석해 새 블랙리스트 항목을 Flutter 앱에서 제안한다.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| Python 신규 | `news_pulse/blocks/blacklist_analyzer.py` | 필터링된 아이템의 키워드/도메인 빈도 분석 |
| Python 신규 | `news_pulse/db/store_analytics.py` | 분석용 쿼리 (필터링 패턴 집계) |
| Python 수정 | `news_pulse/db/store.py` | analytics 관련 위임 메서드 추가 |
| Flutter 신규 | `news_pulse_app/lib/repositories/analytics_repository.dart` | 분석 데이터 조회 |
| Flutter 신규 | `news_pulse_app/lib/providers/blacklist_suggestion_provider.dart` | 제안 목록 상태 |
| Flutter 수정 | `news_pulse_app/lib/screens/settings/settings_screen.dart` | "블랙리스트 제안" 섹션 추가 |
| Flutter 신규 | `news_pulse_app/lib/screens/settings/widgets/blacklist_suggestion_card.dart` | 제안 카드 위젯 (수락/거부 버튼) |

**DB 변경**: 없음 (기존 processed_items + filter_config 데이터를 집계 쿼리로 분석)

**구현 접근**:
- `processed_items`에서 `telegram_sent=0` (필터에 의해 걸러진 아이템)의 제목에서 단어 빈도를 집계한다.
- 상위 빈도 단어 중 현재 블랙리스트에 없는 것을 제안한다.
- 도메인 분석: URL에서 도메인을 추출해 빈도 집계.
- Flutter에서 제안을 표시하고, "추가" 버튼 클릭 시 `filter_config.blacklist_keywords`에 반영한다.
- 주의: `telegram_sent=0`이 반드시 "필터링됨"을 의미하지는 않는다 (아직 전송 전일 수도 있음). 필터링 여부를 정확히 구분하려면 별도 플래그가 필요하지만, 30일 데이터 기준으로 `telegram_sent=0 AND created_at < date('now','-1 day')`로 근사할 수 있다.

**의존**: 없음 (독립)

---

### F09. Threshold Calibration (P2) — 복잡도: M

**설명**: 소스별 과거 통과율 데이터를 분석해 최적 업보트 임계값을 제안한다. 현재 값과 제안 값을 설정 화면에서 비교 표시.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| Python 신규 | `news_pulse/blocks/threshold_calibrator.py` | 통과율 분석 + 최적 임계값 계산 |
| Python 수정 | `news_pulse/db/store_analytics.py` | (F08에서 생성) 소스별 통과율 쿼리 추가 |
| Flutter 신규 | `news_pulse_app/lib/providers/calibration_provider.dart` | 교정 결과 상태 |
| Flutter 수정 | `news_pulse_app/lib/screens/settings/settings_screen.dart` | 임계값 섹션에 "제안" 뱃지 추가 |
| Flutter 신규 | `news_pulse_app/lib/screens/settings/widgets/threshold_suggestion.dart` | 현재 vs 제안 비교 위젯 |

**DB 변경**: 없음 (기존 데이터 집계)

**구현 접근**:
- 소스별로 최근 30일 데이터에서 "수집된 전체 건수" 대 "전송된 건수" 비율을 계산한다.
- 목표 통과율(예: 30-50%)에 맞는 업보트 임계값을 이분 탐색으로 계산한다.
- 현재 임계값 대비 높이거나 낮추라는 제안을 표시한다.
- "적용" 버튼 클릭 시 filter_config를 즉시 업데이트한다.

**의존**: F08과 `store_analytics.py`를 공유한다. 둘을 동시에 구현하면 효율적.

---

### F10. Markdown Export (P2) — 복잡도: S

**설명**: Flutter 앱에서 날짜 범위 또는 핫뉴스를 선택해 .md 파일로 내보낸다.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| Flutter 신규 | `news_pulse_app/lib/services/markdown_exporter.dart` | Markdown 생성 + 파일 저장 서비스 |
| Flutter 수정 | `news_pulse_app/lib/screens/news/news_screen.dart` | 헤더에 "내보내기" 버튼 추가 |
| Flutter 신규 | `news_pulse_app/lib/screens/news/widgets/export_dialog.dart` | 날짜 범위 선택 + 내보내기 옵션 다이얼로그 |
| Flutter 수정 | `news_pulse_app/lib/repositories/news_repository.dart` | `getItemsByDateRange()` 메서드 추가 |

**DB 변경**: 없음

**구현 접근**:
- Markdown 템플릿:
  ```markdown
  # News Pulse Report (2026-04-01 ~ 2026-04-07)

  ## Hot News
  ### [제목](url)
  > 요약 텍스트
  - Source: hackernews | Upvotes: 342

  ## General News
  ...
  ```
- `file_picker` 패키지로 저장 경로 선택 (macOS에서 NSSavePanel 사용).
- 핫뉴스 탭에서도 "핫뉴스만 내보내기" 가능.
- 날짜 범위 기본값: 최근 7일.

**의존**: 없음 (독립)

---

### F11. Menu Bar App (P3) — 복잡도: L

**설명**: macOS 메뉴바에 상태 아이콘을 표시한다. 마지막 실행 상태, 다음 실행 시간, 에러 건수를 보여주고, 클릭 시 빠른 액션(즉시 실행, 앱 열기 등)을 제공한다.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| Flutter 신규 | `news_pulse_app/lib/services/menu_bar_service.dart` | macOS 시스템 트레이 API 래퍼 |
| Flutter 신규 | `news_pulse_app/lib/providers/menu_bar_provider.dart` | 메뉴바 상태 관리 |
| Flutter 수정 | `news_pulse_app/lib/main.dart` | 앱 시작 시 메뉴바 서비스 초기화 |
| Flutter 수정 | `news_pulse_app/macos/Runner/MainFlutterWindow.swift` | NSStatusBar 네이티브 코드 (MethodChannel) |
| Flutter 신규 | `news_pulse_app/lib/core/channels/menu_bar_channel.dart` | MethodChannel 정의 |

**DB 변경**: 없음

**구현 접근**:
- macOS의 `NSStatusBar`를 사용한다. Flutter에서는 `system_tray` 또는 `tray_manager` 패키지를 사용하거나, MethodChannel로 네이티브 구현한다.
- 메뉴 항목: 마지막 실행 상태(성공/실패 + 시간), 다음 실행 예정, 에러 건수, 구분선, 즉시 실행(F02 연동), 앱 열기, 종료.
- 상태 아이콘: 정상=초록 점, 에러=빨간 점, 실행 중=노란 점.
- DB를 주기적으로 폴링(30초)해 상태를 업데이트한다.

**의존**: F02 (Manual Trigger — "즉시 실행" 메뉴 항목)

---

### F12. Source Wizard (P3) — 복잡도: L

**설명**: Flutter GUI 위저드로 코드 수정 없이 새 RSS/API 소스를 추가한다. URL, 파서 타입, 필터 Tier를 설정한다.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| DB 수정 | `news_pulse/db/schema.sql` | 없음 (filter_config으로 관리 가능) |
| Python 수정 | `news_pulse/blocks/config_loader.py` | DB에서 커스텀 소스 목록을 동적으로 로딩 |
| Python 수정 | `news_pulse/models/config.py` | SourceConfig에 `is_custom` 필드 추가 |
| Flutter 신규 | `news_pulse_app/lib/screens/settings/widgets/source_wizard_dialog.dart` | 3단계 위저드 다이얼로그 |
| Flutter 수정 | `news_pulse_app/lib/screens/settings/settings_screen.dart` | "소스 추가" 버튼 |
| Flutter 수정 | `news_pulse_app/lib/repositories/config_repository.dart` | 커스텀 소스 CRUD 메서드 |

**DB 변경**: filter_config에 커스텀 소스를 JSON으로 저장한다. 키: `custom_sources`, 값: JSON 배열.

**구현 접근**:
- 위저드 3단계: (1) URL 입력 + 자동 감지(RSS/Atom/Reddit/API), (2) 소스명/Tier/언어 설정, (3) 연결 테스트 + 미리보기.
- 자동 감지: URL에 `/rss`, `.xml`, `.atom` 포함 시 RSS, `reddit.com` 포함 시 Reddit, `github.com` + `.atom` 시 GitHub Atom.
- 연결 테스트: 해당 URL을 실제 fetch해서 첫 아이템을 미리보기로 표시한다.
- 커스텀 소스는 filter_config에 `custom_sources` 키로 JSON 배열 저장. ConfigLoader가 이를 읽어 `config.sources`에 추가한다.
- 제한: 커스텀 소스는 기존 4가지 fetcher 타입(rss/algolia/reddit/github_atom)만 지원한다. 새 fetcher 타입 추가는 코드 수정이 필요하다.

**의존**: 없음 (독립)

---

### F13. Prompt Tracking (P3) — 복잡도: M

**설명**: 요약/번역 프롬프트를 버전 관리한다. 어떤 프롬프트 버전이 어떤 요약을 생성했는지 추적한다.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| DB 신규 | `news_pulse/db/schema.sql` | prompt_versions 테이블 |
| DB 수정 | `news_pulse/db/schema.sql` | processed_items에 `prompt_version_id` 컬럼 추가 |
| Python 신규 | `news_pulse/db/store_prompts.py` | prompt_versions CRUD SQL |
| Python 수정 | `news_pulse/db/store.py` | prompt 관련 위임 메서드 추가 |
| Python 수정 | `news_pulse/db/store_processed.py` | `_PROCESSED_ITEM_COLUMNS`에 `prompt_version_id` 추가 |
| Python 수정 | `news_pulse/blocks/summarizer/apex_summarizer.py` | DB에서 활성 프롬프트 로드, version_id 기록 |
| Python 수정 | `news_pulse/blocks/summarizer/kanana_summarizer.py` | 동일 |
| Python 수정 | `news_pulse/blocks/summarizer/claude_cli_summarizer.py` | 동일 |
| Python 수정 | `news_pulse/blocks/translator/kanana_translator.py` | 동일 |
| Python 수정 | `news_pulse/blocks/translator/claude_cli_translator.py` | 동일 |
| Flutter 신규 | `news_pulse_app/lib/repositories/prompt_repository.dart` | 프롬프트 CRUD |
| Flutter 신규 | `news_pulse_app/lib/models/prompt_version.dart` | 데이터 모델 |
| Flutter 신규 | `news_pulse_app/lib/providers/prompt_provider.dart` | 프롬프트 상태 관리 |
| Flutter 신규 | `news_pulse_app/lib/screens/settings/widgets/prompt_editor.dart` | 프롬프트 편집/버전 관리 위젯 |
| Flutter 수정 | `news_pulse_app/lib/screens/settings/settings_screen.dart` | "프롬프트 관리" 섹션 추가 |
| Flutter 수정 | `news_pulse_app/lib/core/database/tables.dart` | PromptVersionsCol 추가 |

**DB 변경**: prompt_versions 테이블 신규 생성 (2.1 참조), processed_items에 `prompt_version_id` 컬럼 추가

**구현 접근**:
- 초기 시드: 현재 하드코딩된 프롬프트를 prompt_versions 테이블에 version=1, is_active=1로 삽입한다.
- 각 Summarizer/Translator가 `__init__` 시 DB에서 `is_active=1`인 프롬프트를 로딩한다. DB 조회 실패 시 하드코딩 프롬프트로 폴백.
- 새 프롬프트 저장 시 기존 활성 버전의 `is_active=0`으로 변경 후, 새 버전을 `is_active=1`로 INSERT.
- Flutter에서는 프롬프트 편집기(TextArea) + 버전 이력 리스트 + "이 버전 활성화" 버튼을 제공한다.
- `processed_items.prompt_version_id`로 어떤 프롬프트로 생성된 요약인지 추적 가능.

**의존**: 없음 (독립, F04와 함께 구현하면 상세 보기에서 프롬프트 버전까지 표시 가능)

---

### F14. Telegram Token Management (P4) — 복잡도: M

**설명**: Flutter 설정 화면에서 Telegram 봇 토큰, API 키, 관리자 chat ID 등 민감한 설정값을 안전하게 관리한다. .env 파일 편집 없이 앱에서 직접 수정 가능.

**영향 파일**:

| 유형 | 파일 | 변경 내용 |
|------|------|-----------|
| Flutter 신규 | `news_pulse_app/lib/services/secure_storage_service.dart` | macOS Keychain 래퍼 (flutter_secure_storage 패키지) |
| Flutter 신규 | `news_pulse_app/lib/services/env_writer_service.dart` | .env 파일 읽기/쓰기 서비스 |
| Flutter 신규 | `news_pulse_app/lib/screens/settings/widgets/token_management_section.dart` | 토큰 관리 UI 섹션 |
| Flutter 신규 | `news_pulse_app/lib/screens/settings/widgets/connection_test_button.dart` | 연결 테스트 버튼 위젯 |
| Flutter 수정 | `news_pulse_app/lib/screens/settings/settings_screen.dart` | 토큰 관리 섹션 추가 |
| Flutter 신규 | `news_pulse_app/lib/providers/token_provider.dart` | 토큰 상태 관리 |
| Flutter 수정 | `news_pulse_app/pubspec.yaml` | `flutter_secure_storage` 패키지 추가 |

**DB 변경**: 없음 (민감 정보는 macOS Keychain에 저장, .env 파일도 병행 업데이트)

**구현 접근**:
- **저장 전략**: 민감 값(BOT_TOKEN, ADMIN_CHAT_ID)은 macOS Keychain에 저장한다. 동시에 .env 파일도 업데이트해 Python 파이프라인이 읽을 수 있도록 한다.
- `flutter_secure_storage` 패키지로 Keychain 접근. macOS에서는 Keychain Access를 통해 저장된다.
- `.env` 파일 쓰기: 기존 .env 파일을 읽어 해당 키만 교체 후 다시 쓴다. 파일 잠금에 주의한다.
- **연결 테스트**: BOT_TOKEN 변경 후 `https://api.telegram.org/bot{token}/getMe` 호출로 유효성 검증.
- **UI 구성**: 마스킹된 토큰 표시 (앞 6자만 표시, 나머지 *), "수정" 버튼 클릭 시 입력 필드 표시, "테스트" 버튼, "저장" 버튼.
- 관리 대상 키: `BOT_TOKEN`, `ADMIN_CHAT_ID`, `OLLAMA_ENDPOINT`, `APEX_MODEL_NAME`, `KANANA_MODEL_NAME`, `MEMORY_THRESHOLD_GB`.

**의존**: 없음 (독립)

---

## 4. 의존 관계 및 구현 순서

### 4.1 의존 관계 그래프

```
F01 (Whitelist)      ← 독립
F02 (Manual Trigger) ← 독립
F03 (Read Status)    ← 독립
F04 (Model Trace)    ← 독립
F05 (Skip Detect)    ← F02 (캐치업 UI 연동)
F06 (Latency)        ← F04 (모델명 기록 공유, 필수 아님)
F07 (Digest)         ← 독립
F08 (Blacklist Sug)  ← 독립
F09 (Threshold Cal)  ← F08 (store_analytics.py 공유)
F10 (MD Export)      ← 독립
F11 (Menu Bar)       ← F02 (즉시 실행 메뉴)
F12 (Source Wizard)  ← 독립
F13 (Prompt Track)   ← 독립
F14 (Token Mgmt)     ← 독립
```

### 4.2 권장 구현 순서

DB 스키마 변경이 있는 기능을 먼저 묶어 1회의 마이그레이션으로 처리한다.

**Wave 1 — DB 스키마 + 핵심 파이프라인** (병렬 가능)
1. DB 마이그레이션 통합 (모든 ALTER + CREATE TABLE 한 번에)
2. F03 (Read Status) — S, 독립, DB 변경 포함
3. F04 (Model Traceability) — M, 독립, DB 변경 포함
4. F01 (Keyword Whitelist) — M, 독립, DB 변경 포함

**Wave 2 — 파이프라인 확장** (Wave 1 이후)
5. F02 (Manual Trigger) — L, 독립
6. F06 (Latency Trending) — M, F04 이후 효율적
7. F13 (Prompt Tracking) — M, DB 변경 포함

**Wave 3 — 분석 기능** (병렬 가능)
8. F08 (Blacklist Suggestion) — M
9. F09 (Threshold Calibration) — M, F08과 동시
10. F05 (Skip Detection) — M, F02 이후

**Wave 4 — 편의 기능** (병렬 가능)
11. F07 (Digest Mode) — L
12. F10 (Markdown Export) — S
13. F14 (Telegram Token Mgmt) — M

**Wave 5 — 고급 기능** (Wave 2 이후)
14. F12 (Source Wizard) — L
15. F11 (Menu Bar App) — L, F02 이후

---

## 5. seed 데이터 추가 계획

```sql
-- F01: 화이트리스트 기본 키워드 (비어있는 상태로 시작)
-- seed 불필요 — 사용자가 Flutter에서 직접 추가

-- F07: 다이제스트 모드 설정
INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('digest_enabled', 'false', '다이제스트 모드 활성화 (true=묶어서 발송, false=개별 발송)');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('digest_hour', '9', '다이제스트 발송 시간 (0-23, 기본 09시)');

-- F13: 초기 프롬프트 버전 (현재 하드코딩된 프롬프트를 DB로 이관)
INSERT OR IGNORE INTO prompt_versions (prompt_type, version, content, is_active) VALUES
    ('summarize_ko', 1, '다음 뉴스를 한국어로 2-3문장으로 간결하게 요약해주세요.

제목: {title}
내용: {content}

요약:', 1);

INSERT OR IGNORE INTO prompt_versions (prompt_type, version, content, is_active) VALUES
    ('summarize_en', 1, 'Summarize the following news in 2-3 concise sentences in English.

Title: {title}
Content: {content}

Summary:', 1);

INSERT OR IGNORE INTO prompt_versions (prompt_type, version, content, is_active) VALUES
    ('translate', 1, '다음 영어 텍스트를 자연스러운 한국어로 번역해주세요. 기술 용어는 영어를 유지해도 됩니다.

원문: {text}

번역:', 1);
```

---

## 6. 에이전트별 작업 배정

### backend-db 에이전트
- `schema.sql` 수정: 4개 새 테이블 + 4개 ALTER TABLE
- `seed.sql` 수정: 다이제스트/프롬프트 시드 데이터
- `migrate.py` 수정: `_EXPECTED_TABLE_COUNT` 7->11, `_apply_alter_tables` 함수 추가
- `store_whitelist.py` 신규
- `store_model_usage.py` 신규
- `store_schedule.py` 신규
- `store_prompts.py` 신규
- `store_analytics.py` 신규
- `store.py` 수정: 5개 신규 모듈 위임 메서드 추가
- `store_processed.py` 수정: `_PROCESSED_ITEM_COLUMNS` 확장

### backend-api 에이전트
- F01: `whitelist_filter.py` 신규, `tier_router.py` 수정
- F02: `__main__.py` 수정 (`--manual-trigger`, `--catchup`, `--digest` 인수)
- F04: `summarize_pipeline.py` 수정, 각 Summarizer/Translator에 `model_display_name` 추가
- F05: `skip_detector.py` 신규
- F06: `model_usage_tracker.py` 신규, `summarize_pipeline.py` 수정
- F07: `digest_formatter.py` 신규, `digest_pipeline.py` 신규
- F08: `blacklist_analyzer.py` 신규
- F09: `threshold_calibrator.py` 신규
- F12: `config_loader.py` 수정 (커스텀 소스 로딩)
- F13: 각 Summarizer/Translator 수정 (프롬프트 DB 로딩)
- `orchestrator.py` 수정: WhitelistFilter 주입, SkipDetector 호출, digest 분기
- `models/config.py` 수정: `digest_enabled`, `digest_hour` 필드 추가

### app-frontend 에이전트
- F01: `whitelist_repository.dart`, `whitelist_keyword.dart`, `whitelist_provider.dart`, `keyword_chip_input.dart` 신규
- F02: `pipeline_runner.dart`, `manual_trigger_provider.dart`, `manual_trigger_button.dart`, `trigger_result_dialog.dart` 신규
- F03: `processed_item.dart` 수정, `news_repository.dart` 수정, `news_provider.dart` 수정, `news_list_tile.dart` 수정, `news_detail_dialog.dart` 수정, `unread_count_card.dart` 신규
- F04: `processed_item.dart` 수정, `news_detail_content.dart` 수정
- F05: `schedule_repository.dart`, `schedule_log.dart`, `schedule_provider.dart`, `missed_run_banner.dart` 신규
- F06: `model_usage_repository.dart`, `model_usage.dart`, `model_usage_provider.dart`, `latency_chart.dart` 신규
- F07: `digest_settings.dart` 신규
- F08: `analytics_repository.dart`, `blacklist_suggestion_provider.dart`, `blacklist_suggestion_card.dart` 신규
- F09: `calibration_provider.dart`, `threshold_suggestion.dart` 신규
- F10: `markdown_exporter.dart`, `export_dialog.dart` 신규, `news_screen.dart` 수정
- F11: `menu_bar_service.dart`, `menu_bar_provider.dart`, `menu_bar_channel.dart` 신규, `main.dart` 수정, Swift 코드 수정
- F12: `source_wizard_dialog.dart` 신규, `config_repository.dart` 수정
- F13: `prompt_repository.dart`, `prompt_version.dart`, `prompt_provider.dart`, `prompt_editor.dart` 신규
- F14: `secure_storage_service.dart`, `env_writer_service.dart`, `token_management_section.dart`, `connection_test_button.dart`, `token_provider.dart` 신규
- `settings_screen.dart` 수정: F01/F07/F08/F09/F12/F13/F14 섹션 추가
- `home_screen.dart` 수정: F02/F03/F05 위젯 추가
- `stats_screen.dart` 수정: F06 차트 추가
- `tables.dart` 수정: 새 테이블/컬럼 상수 추가

### devops-engineer 에이전트
- F11: `MainFlutterWindow.swift` 수정 (NSStatusBar 네이티브 구현)
- `pubspec.yaml` 수정: `flutter_secure_storage`, `file_picker` 패키지 추가

---

## 7. 주의사항

### 7.1 파일 크기 제한 준수
- `settings_screen.dart`가 현재 200줄. 7개 기능이 섹션을 추가하므로 반드시 각 섹션을 별도 위젯 파일로 분리해야 한다. `settings_screen.dart`는 섹션 조립만 담당 (50줄 이내 목표).
- `orchestrator.py`가 현재 106줄. 신규 블럭 추가 시 import가 많아지므로 `__init__` DI 조립부를 별도 `_build_blocks` 팩토리 메서드로 분리한다.
- `store.py`가 현재 192줄. 5개 신규 모듈 위임 메서드 추가 시 200줄 초과가 예상되므로, 메서드를 기능별로 그룹핑하고 필요 시 `store_v2.py`로 분리한다.

### 7.2 SQLite 동시 접근
- Python과 Flutter가 동시에 같은 DB에 접근한다. 이미 WAL 모드 + busy_timeout=5000ms가 설정되어 있으므로 기본적으로 안전하다.
- F02 (Manual Trigger)에서 Python 파이프라인이 실행되는 동안 Flutter가 DB를 읽는 경우가 잦아지므로, WAL checkpoint가 밀리지 않도록 주의한다.

### 7.3 마이그레이션 멱등성
- ALTER TABLE은 IF NOT EXISTS를 지원하지 않는다. `PRAGMA table_info`로 컬럼 존재 여부를 확인 후 조건부 실행한다.
- 기존 데이터에 새 컬럼이 추가될 때 DEFAULT 값이 올바른지 확인한다 (is_read=0, summarizer_model=NULL).

### 7.4 기존 테스트 호환
- `news_pulse/tests/` 디렉터리에 기존 테스트가 있다면, DB 스키마 변경 후에도 테스트가 통과해야 한다.
- `_EXPECTED_TABLE_COUNT` 변경이 기존 마이그레이션 테스트에 영향을 줄 수 있다.

### 7.5 민감 정보 보안 (F14)
- BOT_TOKEN은 절대 DB(filter_config)에 저장하지 않는다. macOS Keychain + .env 파일만 사용한다.
- .env 파일 쓰기 시 파일 퍼미션 0600을 유지한다.
- Flutter 로그에 토큰이 출력되지 않도록 주의한다.

### 7.6 Telegram 메시지 크기 (F07)
- Telegram 메시지 최대 4096자. 다이제스트 모드에서 하루치 뉴스가 이를 초과할 수 있다.
- 4096자 초과 시 자동 분할 발송한다. 분할 시 아이템 중간에서 자르지 않는다.

### 7.7 모델명 일관성 (F04/F06)
- Python 블럭에서 사용하는 모델명과 DB에 기록되는 모델명이 일치해야 한다.
- Config에서 정의된 `apex_model_name`, `kanana_model_name`을 그대로 사용하고, Claude CLI는 `"claude-cli"`로 통일한다.
