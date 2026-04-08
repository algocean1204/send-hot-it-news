-- news-pulse 시드 데이터
-- INSERT OR IGNORE로 멱등성 보장 (중복 실행 시 에러 없음)

-- ============================================================
-- filter_config 시드 데이터 (19건)
-- 소스 ON/OFF, 필터 임계값 등 기본 설정값
-- ============================================================

-- 소스 활성화 설정 (12건)
INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_geeknews_enabled',             'true',  'GeekNews RSS 활성화');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_hackernews_enabled',           'true',  'Hacker News Algolia API 활성화');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_reddit_localllama_enabled',    'true',  'r/LocalLLaMA 활성화');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_reddit_claudeai_enabled',      'true',  'r/ClaudeAI 활성화');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_reddit_cursor_enabled',        'true',  'r/Cursor 활성화');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_anthropic_enabled',            'true',  'Anthropic News RSS 활성화');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_openai_enabled',               'true',  'OpenAI News RSS 활성화');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_deepmind_enabled',             'true',  'DeepMind Blog RSS 활성화');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_huggingface_enabled',          'true',  'HuggingFace Blog RSS 활성화');

-- source_claude_code_releases_enabled: P2-1 수정 — 올바른 source_id 반영
INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_claude_code_releases_enabled', 'true',  'Claude Code GitHub Atom 활성화');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    -- source_id="cline_releases"에 대응하는 정확한 키명 사용
    ('source_cline_releases_enabled',       'true',  'Cline GitHub Atom 활성화');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('source_cursor_changelog_enabled',     'true',  'Cursor Changelog RSS 활성화');

-- 필터 임계값 설정 (7건)
-- tier3_hn_threshold: ConfigLoader가 읽는 정식 키
INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('tier3_hn_threshold',              '50',    'HN Tier3 최소 업보트 (ConfigLoader 읽기용, 구 hn_min_points)');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('hn_young_min_points',             '20',    'HN 최소 업보트 (2시간 미만 게시물 완화)');

-- tier3_reddit_threshold: ConfigLoader가 읽는 정식 키
INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('tier3_reddit_threshold',          '25',    'Reddit Tier3 최소 업보트 (ConfigLoader 읽기용, 구 reddit_localllama_min_upvotes)');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('reddit_claudeai_min_upvotes',     '10',    'r/ClaudeAI 최소 업보트');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('reddit_cursor_min_upvotes',       '10',    'r/Cursor 최소 업보트');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('max_items_per_run',               '8',     '시간당 최대 전송 건수');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('allow_tier1_overflow',            'true',  'Tier 1+2 할당량 초과 시 Tier 3 허용 여부');

-- ============================================================
-- subscribers 시드 데이터 (1건)
-- 관리자 계정. chat_id는 실제 운영 시 .env의 ADMIN_CHAT_ID 값으로 교체해야 한다.
-- 여기서는 개발/테스트용 플레이스홀더 값을 사용한다.
-- ============================================================
INSERT OR IGNORE INTO subscribers (chat_id, username, first_name, status, is_admin)
VALUES (123456789, 'admin_user', 'Admin', 'approved', 1);

-- ============================================================
-- filter_config 시드 데이터 — F07 다이제스트 설정 (2건)
-- ============================================================
INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('digest_enabled', 'false', '다이제스트 모드 활성화 (true=묶어서 발송, false=개별 발송)');

INSERT OR IGNORE INTO filter_config (key, value, description) VALUES
    ('digest_hour', '9', '다이제스트 발송 시간 (0-23, 기본 09시)');

-- ============================================================
-- prompt_versions 시드 데이터 — 초기 프롬프트 3종 (is_active=1)
-- 운영 중 버전 교체 시 create_version() 함수로 자동 증가한다.
-- ============================================================
INSERT OR IGNORE INTO prompt_versions (prompt_type, version, content, is_active) VALUES
    ('summarize_ko', 1,
     '다음 기술 뉴스를 한국어로 3문장 이내로 요약하세요. 핵심 내용, 의의, 영향을 포함하세요.',
     1);

INSERT OR IGNORE INTO prompt_versions (prompt_type, version, content, is_active) VALUES
    ('summarize_en', 1,
     'Summarize the following tech news in 3 sentences or less. Include key points, significance, and impact.',
     1);

INSERT OR IGNORE INTO prompt_versions (prompt_type, version, content, is_active) VALUES
    ('translate', 1,
     '다음 영어 텍스트를 자연스러운 한국어로 번역하세요. 기술 용어는 원문을 괄호 안에 병기하세요.',
     1);
