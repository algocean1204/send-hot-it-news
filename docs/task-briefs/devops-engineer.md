# Task Brief: devops-engineer

## 프로젝트 개요

news-pulse: 12개 IT/AI 소스에서 뉴스를 수집하고, 로컬 LLM으로 요약/번역 후 텔레그램으로 시간당 1회 푸시하는 macOS 전용 봇.
macOS launchd로 트리거, 상시 프로세스 없음. MacBook Pro M4 Pro (48GB) 단일 머신에서 실행.

---

## 기술 스택

| 항목 | 버전/도구 |
|------|-----------|
| Python | 3.12 |
| 패키지 매니저 | uv (pyproject.toml) |
| 추론 엔진 | Ollama (GGUF 모델) |
| 스케줄러 | macOS launchd (LaunchAgent) |
| 실행 환경 | MacBook Pro M4 Pro, macOS |

---

## 담당 범위

1. pyproject.toml 설정 (uv 패키지 관리)
2. .env.example 템플릿
3. Setup 스크립트 (Ollama 모델 다운로드/등록)
4. launchd plist 생성 (16시간대 스케줄)
5. install/uninstall 스크립트

---

## 생성할 파일 구조

```
news-pulse/                        # 프로젝트 루트
├── pyproject.toml                 # uv 패키지 설정
├── .env.example                   # 환경변수 템플릿
├── scripts/
│   ├── setup.sh                   # Ollama 모델 다운로드/등록
│   ├── install_launchd.sh         # launchd 등록
│   ├── uninstall_launchd.sh       # launchd 해제
│   └── health_check.sh            # 수동 헬스체크 실행
├── launchd/
│   └── com.news-pulse.bot.plist   # launchd 설정 파일
└── .gitignore
```

---

## 모듈 상세 스펙

### 1. pyproject.toml

```toml
[project]
name = "news-pulse"
version = "1.0.0"
description = "IT/AI 뉴스 자동 수집, 로컬 LLM 요약, 텔레그램 푸시 봇"
requires-python = ">=3.12"

dependencies = [
    "httpx",
    "feedparser",
    "python-dotenv",
    "psutil",
    "lingua-language-detector",
]

[project.optional-dependencies]
dev = [
    "pytest",
    "pytest-asyncio",
    "ruff",
]

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]

[tool.ruff]
target-version = "py312"
line-length = 120

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B"]
```

**주의**: 모든 의존성은 정확한 버전 핀 없이 명시 (uv.lock이 버전 고정을 처리).

---

### 2. .env.example

```env
# === news-pulse 환경변수 ===

# 텔레그램 봇 토큰 (BotFather에서 발급)
BOT_TOKEN=your_bot_token_here

# 관리자 텔레그램 chat_id
ADMIN_CHAT_ID=your_chat_id_here

# SQLite DB 경로
DB_PATH=~/.news-pulse/news_pulse.db

# Ollama 엔드포인트
OLLAMA_ENDPOINT=http://localhost:11434

# 모델 이름
APEX_MODEL_NAME=apex-i-compact
KANANA_MODEL_NAME=kanana-2-30b

# 메모리 임계값 (GB) -- 이 값 미만이면 Claude CLI 폴백
MEMORY_THRESHOLD_GB=26.0

# 로그 경로
LOG_PATH=~/.news-pulse/logs/news_pulse.log
```

---

### 3. Setup 스크립트 (scripts/setup.sh)

**IN**: 없음 (사전 조건: Ollama 설치됨)
**OUT**: Ollama에 APEX, Kanana 모델 등록 완료

**내부 로직**:

```bash
#!/bin/bash
# news-pulse 초기 설정 스크립트
# Ollama 모델 다운로드 및 등록

set -euo pipefail

# 1. Ollama 실행 확인
# 2. APEX 모델 다운로드 (ollama pull)
# 3. Kanana 모델 다운로드 (ollama pull)
# 4. 모델 등록 확인 (ollama list)
# 5. 간단한 추론 테스트 (ollama run ... "Hello")
# 6. Python 환경 설정 (uv sync)
# 7. DB 초기화 (python -m news_pulse.db.migrate)
# 8. .env 파일 존재 확인
```

**단계별 상세**:

1. `ollama --version` 확인. 없으면 설치 안내 메시지 + exit 1
2. `ollama pull apex-i-compact` (모델명은 실제 Ollama 레지스트리 확인 필요)
3. `ollama pull kanana-2-30b` (모델명은 실제 확인 필요)
4. `ollama list`로 두 모델 등록 확인
5. 각 모델로 간단한 테스트 프롬프트 실행, 응답 확인
6. `uv sync` 실행 (Python 의존성 설치)
7. `uv run python -m news_pulse.db.migrate` (DB 스키마 + 시드)
8. `.env` 파일 존재 확인. 없으면 `.env.example` 복사 안내

**에러 처리**:
- 각 단계 실패 시 명확한 에러 메시지 + exit 1
- 모델 다운로드 실패 -> 재시도 안내

---

### 4. launchd plist (launchd/com.news-pulse.bot.plist)

**스케줄**: 매일 09:00 ~ 00:00, 매시 정각 (16회/일). 01:00~08:00 제외 (수면 시간).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.news-pulse.bot</string>

    <key>ProgramArguments</key>
    <array>
        <string>/path/to/uv</string>
        <string>run</string>
        <string>python</string>
        <string>-m</string>
        <string>news_pulse</string>
    </array>

    <key>WorkingDirectory</key>
    <string>/path/to/news-pulse</string>

    <key>StartCalendarInterval</key>
    <array>
        <!-- 09:00 ~ 00:00 매시 정각 (16개) -->
        <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>12</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>13</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>15</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>16</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>17</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>19</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>22</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>23</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Hour</key><integer>0</integer><key>Minute</key><integer>0</integer></dict>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
        <key>TZ</key>
        <string>Asia/Seoul</string>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>

    <key>StandardOutPath</key>
    <string>/tmp/news-pulse-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/news-pulse-stderr.log</string>

    <key>ExitTimeOut</key>
    <integer>300</integer>

    <key>ProcessType</key>
    <string>Background</string>

    <key>RunAtLoad</key>
    <false/>

    <key>AbandonProcessGroup</key>
    <false/>
</dict>
</plist>
```

**주의사항**:
- `ProgramArguments`의 경로는 install 스크립트에서 동적으로 치환
- TZ 이중 고정: plist EnvironmentVariables + Python `os.environ['TZ']`
- KeepAlive 미설정 (상시 프로세스 아님)
- RunAtLoad=false (시스템 부팅 시 자동 실행 안 함)
- ExitTimeOut=300초 (5분 후 강제 종료)

---

### 5. install/uninstall 스크립트

#### scripts/install_launchd.sh

```bash
#!/bin/bash
# launchd에 news-pulse 봇 등록

set -euo pipefail

PLIST_NAME="com.news-pulse.bot"
PLIST_SRC="$(cd "$(dirname "$0")/.." && pwd)/launchd/${PLIST_NAME}.plist"
PLIST_DST="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UV_PATH="$(which uv)"

# 1. uv 경로 확인
# 2. plist 파일 복사 + 경로 치환 (sed)
#    - /path/to/uv -> 실제 uv 경로
#    - /path/to/news-pulse -> 실제 프로젝트 경로
# 3. ~/Library/LaunchAgents/ 에 복사
# 4. launchctl load
# 5. 등록 확인 (launchctl list | grep news-pulse)
```

#### scripts/uninstall_launchd.sh

```bash
#!/bin/bash
# launchd에서 news-pulse 봇 해제

set -euo pipefail

PLIST_NAME="com.news-pulse.bot"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

# 1. launchctl unload
# 2. plist 파일 삭제
# 3. 해제 확인
```

---

### 6. health_check.sh

```bash
#!/bin/bash
# 수동 헬스체크 실행 (Flutter 앱에서도 subprocess로 호출)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

uv run python -m news_pulse --health-check
```

---

### 7. .gitignore

```gitignore
# Python
__pycache__/
*.pyc
*.pyo
*.egg-info/
dist/
build/
.venv/

# uv
.uv/

# 환경변수 (시크릿)
.env

# DB
*.db
*.db-wal
*.db-shm

# 로그
*.log
logs/

# macOS
.DS_Store

# IDE
.idea/
.vscode/
*.swp
*.swo

# Flutter (별도 프로젝트)
news_pulse_app/

# 테스트
.coverage
htmlcov/
.pytest_cache/
```

---

## 안전성 설정 참조

| 항목 | 설정 |
|------|------|
| ExitTimeOut | 300초 |
| subprocess timeout | 300초 |
| KeepAlive | 미설정 |
| RunAtLoad | false |
| ProcessType | Background |
| AbandonProcessGroup | false |
| signal handler | SIGTERM -> cleanup + exit |

슬립 복귀 시 +-10분 검증, 벗어나면 skip (이 로직은 backend-api의 orchestrator에서 구현).

---

## 의존성

### 다른 에이전트와의 접점
- **backend-db**: setup.sh에서 DB 마이그레이션 호출 (`python -m news_pulse.db.migrate`)
- **backend-api**: plist에서 `python -m news_pulse` 실행. health_check.sh에서 `--health-check` 플래그 사용
- **app-frontend**: Flutter 앱에서 health_check.sh를 subprocess로 호출

### 선행 조건
- backend-db, backend-api의 엔트리포인트가 정의되어 있어야 plist/스크립트가 동작
- 단, 파일 생성 자체는 독립적으로 가능 (경로만 올바르면 됨)

---

## 코딩 규칙

1. 모든 스크립트 주석은 한국어로 작성
2. `set -euo pipefail` 필수 (bash strict mode)
3. 사용자 입력 경로에 공백 대응 (변수 따옴표 처리)
4. 색상 출력으로 성공/실패 구분 (green/red)
5. 각 단계 시작/완료 메시지 출력
6. pyproject.toml의 모든 의존성은 정확한 버전 핀 필요 없음 (uv.lock이 처리)

---

## 테스트 요구사항

1. plist XML 유효성 검증 (`plutil -lint`)
2. install/uninstall 스크립트 dry-run 모드 (실제 등록 없이 경로/파일 확인)
3. .env.example의 모든 키가 backend-api의 ConfigLoader에서 사용되는지 교차 검증

---

## Checkpoint Protocol

각 파일 완료 후:
1. 이 brief의 해당 모듈 스펙을 다시 읽는다
2. 경로, 파일명, 설정값이 스펙과 일치하는지 검증한다
3. 다음 파일로 진행한다
4. 이 brief에 없는 파일은 절대 생성하지 않는다
