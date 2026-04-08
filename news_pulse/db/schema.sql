-- news-pulse SQLite 스키마 DDL
-- WAL 모드, FK 제약조건, busy_timeout 설정 포함
-- 마이그레이션 순서: filter_config -> subscribers -> processed_items
--                  -> hot_news -> run_history -> error_log -> health_check_results

-- PRAGMA 초기화 (모든 테이블 생성 전 실행)
PRAGMA journal_mode=WAL;         -- WAL 모드 활성화 (읽기/쓰기 동시 접근 허용)
PRAGMA busy_timeout=5000;        -- 잠금 대기 최대 5초 (Flutter 동시 접근 대비)
PRAGMA foreign_keys=ON;          -- FK 제약조건 활성화
PRAGMA synchronous=NORMAL;       -- WAL 모드 권장 동기화 수준 (성능/안전 균형)

-- ============================================================
-- 테이블 1: filter_config (영구 보관)
-- 소스 ON/OFF, 필터 임계값 등 런타임 설정을 key-value로 저장한다.
-- ConfigLoader와 Flutter 화면 7(설정)이 읽고 쓴다.
-- ============================================================
CREATE TABLE IF NOT EXISTS filter_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,                 -- 설정 키 (예: source_geeknews_enabled)
    value TEXT NOT NULL,                       -- 설정 값 (모두 문자열로 저장)
    description TEXT,                          -- 설정 설명 (관리자 참고용)
    updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE INDEX IF NOT EXISTS idx_config_key ON filter_config(key);

-- ============================================================
-- 테이블 2: subscribers (영구 보관)
-- 텔레그램 구독자 정보. pending -> approved/rejected 상태 전이.
-- SubscriberPoller가 쓰고, TelegramSender가 읽는다.
-- ============================================================
CREATE TABLE IF NOT EXISTS subscribers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chat_id INTEGER UNIQUE NOT NULL,          -- 텔레그램 chat_id (중복 불가)
    username TEXT,                             -- 텔레그램 @username
    first_name TEXT,                           -- 텔레그램 이름
    status TEXT NOT NULL DEFAULT 'pending',   -- 구독 상태: pending / approved / rejected
    requested_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    approved_at TEXT,                          -- 승인 시각 (NULL = 미승인)
    rejected_at TEXT,                          -- 거부 시각 (NULL = 미거부)
    is_admin INTEGER DEFAULT 0                -- 관리자 여부 (0=일반, 1=관리자)
);

CREATE INDEX IF NOT EXISTS idx_subs_chat_id ON subscribers(chat_id);
CREATE INDEX IF NOT EXISTS idx_subs_status ON subscribers(status);

-- ============================================================
-- 테이블 3: processed_items (30일 보관)
-- 처리 완료된 뉴스 아이템. 파이프라인이 쓰고, Flutter 화면 1/2/6이 읽는다.
-- is_hot=1인 경우 hot_news에 복사 후 30일 경과 시 삭제.
-- ============================================================
CREATE TABLE IF NOT EXISTS processed_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    url_hash TEXT UNIQUE NOT NULL,            -- SHA-256 해시 (Dedup 중복 체크용)
    url TEXT NOT NULL,                         -- 원문 URL
    title TEXT NOT NULL,                       -- 기사 제목
    source TEXT NOT NULL,                      -- 소스명 (geeknews, hackernews 등)
    language TEXT NOT NULL DEFAULT 'en',       -- 언어 코드 (ko/en)
    raw_content TEXT,                          -- 원본 콘텐츠 (선택적, 용량 절약 가능)
    summary_ko TEXT,                           -- 한국어 요약 텍스트
    tags TEXT,                                 -- 태그 (JSON 배열 문자열, 예: '["AI","LLM"]')
    upvotes INTEGER DEFAULT 0,                -- 업보트 수 (HN/Reddit 전용, 나머지는 0)
    is_hot INTEGER DEFAULT 0,                 -- 핫뉴스 여부 (0=일반, 1=핫)
    pipeline_path TEXT,                        -- 처리 경로 (apex/kanana/claude)
    processing_time_ms INTEGER,               -- 처리 소요시간 (밀리초)
    telegram_sent INTEGER DEFAULT 0,          -- 텔레그램 전송 여부 (0=미전송, 1=전송)
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE INDEX IF NOT EXISTS idx_processed_url_hash ON processed_items(url_hash);
CREATE INDEX IF NOT EXISTS idx_processed_created ON processed_items(created_at);
CREATE INDEX IF NOT EXISTS idx_processed_source ON processed_items(source);

-- ============================================================
-- 테이블 4: hot_news (영구 보관)
-- 핫뉴스로 판정된 아이템. processed_items가 30일 후 삭제되어도 영구 보관.
-- HotNewsDetector가 쓰고, Flutter 화면 2가 읽는다.
-- ============================================================
CREATE TABLE IF NOT EXISTS hot_news (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    -- 원본 뉴스 참조. processed_items는 30일 후 삭제되므로 nullable로 허용.
    -- processed_items 삭제 시 ON DELETE SET NULL으로 참조 무효화.
    processed_item_id INTEGER,
    url TEXT NOT NULL,                         -- 원문 URL (비정규화, 독립 조회용)
    title TEXT NOT NULL,                       -- 기사 제목 (비정규화)
    source TEXT NOT NULL,                      -- 소스명 (비정규화)
    summary_ko TEXT NOT NULL,                 -- 한국어 요약 (비정규화, 영구 보관 목적)
    tags TEXT,                                 -- 태그 (JSON 배열 문자열)
    upvotes INTEGER DEFAULT 0,                -- 업보트 수
    hot_reason TEXT NOT NULL,                  -- 판단 근거: upvote_auto / source_auto / manual
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    FOREIGN KEY (processed_item_id) REFERENCES processed_items(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_hot_created ON hot_news(created_at);
CREATE INDEX IF NOT EXISTS idx_hot_news_processed ON hot_news(processed_item_id);

-- ============================================================
-- 테이블 5: run_history (90일 보관)
-- 파이프라인 실행 기록. RunLogger가 쓰고, Flutter 화면 1/4/6이 읽는다.
-- ============================================================
CREATE TABLE IF NOT EXISTS run_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at TEXT NOT NULL,                  -- 실행 시작 시각
    finished_at TEXT,                           -- 실행 종료 시각 (실행 중이면 NULL)
    status TEXT NOT NULL DEFAULT 'running',    -- running / success / partial_failure / failure
    fetched_count INTEGER DEFAULT 0,           -- 수집 건수
    filtered_count INTEGER DEFAULT 0,          -- 필터 통과 건수
    summarized_count INTEGER DEFAULT 0,        -- 요약 완료 건수
    sent_count INTEGER DEFAULT 0,              -- 텔레그램 전송 건수
    total_duration_ms INTEGER,                -- 총 소요 시간 (밀리초)
    model_load_ms INTEGER,                    -- 모델 로드 시간 (밀리초)
    inference_ms INTEGER,                     -- 추론 시간 (밀리초)
    memory_mode TEXT,                          -- 메모리 모드 (local_llm / claude_fallback)
    error_message TEXT                         -- 에러 메시지 (실패 시만 존재)
);

CREATE INDEX IF NOT EXISTS idx_run_started ON run_history(started_at);

-- ============================================================
-- 테이블 6: error_log (30일 보관)
-- 에러 로그. ErrorNotifier가 쓰고, Flutter 화면 5가 읽는다.
-- run_id는 실행 중 에러만 존재 (nullable).
-- ============================================================
CREATE TABLE IF NOT EXISTS error_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    -- run_id는 nullable: run_history 레코드 삭제 시 ON DELETE SET NULL으로 무효화
    run_id INTEGER,                            -- 실행 참조 (nullable: 실행 외 에러는 NULL)
    severity TEXT NOT NULL DEFAULT 'error',    -- info / warning / error / critical
    module TEXT NOT NULL,                       -- 에러 발생 모듈명
    message TEXT NOT NULL,                      -- 에러 메시지
    traceback TEXT,                             -- Python 스택 트레이스 (선택적)
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    FOREIGN KEY (run_id) REFERENCES run_history(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_error_created ON error_log(created_at);
CREATE INDEX IF NOT EXISTS idx_error_severity ON error_log(severity);

-- ============================================================
-- 테이블 7: health_check_results (7일 보관)
-- 헬스체크 결과. HealthChecker가 쓰고, Flutter 화면 5가 읽는다.
-- ============================================================
CREATE TABLE IF NOT EXISTS health_check_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    check_type TEXT NOT NULL,                  -- ollama / source / telegram / db / disk
    target TEXT NOT NULL,                       -- 체크 대상 (모델명, 소스 URL, 서비스명 등)
    status TEXT NOT NULL,                       -- ok / warning / error
    message TEXT,                               -- 상태 메시지
    response_time_ms INTEGER,                 -- 응답 시간 (밀리초)
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE INDEX IF NOT EXISTS idx_health_created ON health_check_results(created_at);

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
