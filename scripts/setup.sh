#!/bin/bash
# news-pulse 초기 설정 스크립트
# Ollama 모델 다운로드 및 등록, Python 환경 초기화를 수행한다.
# 사전 조건: Ollama가 설치되어 있어야 한다.

set -euo pipefail

# --------------------------------------------------
# 색상 출력 정의
# --------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 색상 초기화

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
fail() { echo -e "${RED}[실패]${NC} $*"; }
info() { echo -e "${YELLOW}[정보]${NC} $*"; }

# --------------------------------------------------
# 프로젝트 루트 경로 설정
# --------------------------------------------------
# 스크립트 위치 기준으로 부모 디렉토리(프로젝트 루트)를 계산한다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --------------------------------------------------
# Ollama 레지스트리 모델명 변수
# 모델명이 확정되면 아래 변수를 실제 값으로 교체하세요.
# 예) APEX_OLLAMA_TAG="bartowski/apex-i-compact-q4_k_m"
# --------------------------------------------------
# APEX I-Compact: Qwen3.5-35B-A3B 기반 GGUF (placeholder)
APEX_OLLAMA_TAG="${APEX_MODEL_NAME:-apex-i-compact}"
# Kanana-2-30B-A3B Q4_K_M 양자화 GGUF (placeholder)
KANANA_OLLAMA_TAG="${KANANA_MODEL_NAME:-kanana-2-30b}"

echo ""
echo "================================================================"
echo "  news-pulse 초기 설정을 시작한다"
echo "================================================================"
echo ""

# --------------------------------------------------
# 단계 1: Ollama 실행 확인
# --------------------------------------------------
info "[1/8] Ollama 설치 및 실행 상태를 확인한다..."

if ! command -v ollama &>/dev/null; then
    fail "Ollama가 설치되어 있지 않다."
    echo "  설치 방법: https://ollama.com/download"
    exit 1
fi

OLLAMA_VER="$(ollama --version 2>&1 || true)"
ok "Ollama 발견: ${OLLAMA_VER}"

# Ollama 서버 응답 확인
if ! curl -sf "${OLLAMA_ENDPOINT:-http://localhost:11434}" &>/dev/null; then
    info "Ollama 서버가 실행 중이지 않다. 백그라운드로 기동을 시도한다..."
    ollama serve &>/dev/null &
    OLLAMA_PID=$!
    sleep 3  # 서버 기동 대기
    if ! curl -sf "${OLLAMA_ENDPOINT:-http://localhost:11434}" &>/dev/null; then
        fail "Ollama 서버 기동 실패 (PID: ${OLLAMA_PID})"
        echo "  직접 실행: ollama serve"
        exit 1
    fi
    ok "Ollama 서버 기동 완료 (PID: ${OLLAMA_PID})"
else
    ok "Ollama 서버 이미 실행 중"
fi

# --------------------------------------------------
# 단계 2: APEX I-Compact 모델 다운로드
# --------------------------------------------------
info "[2/8] APEX I-Compact 모델을 다운로드한다: ${APEX_OLLAMA_TAG}"
echo "  ※ 모델 파일이 크므로 시간이 소요될 수 있다."
echo "  ※ 모델명이 올바르지 않으면 .env 파일의 APEX_MODEL_NAME을 수정하세요."
echo ""

if ollama list 2>/dev/null | grep -q "^${APEX_OLLAMA_TAG}"; then
    ok "APEX 모델이 이미 등록되어 있다. 다운로드를 건너뛴다."
else
    if ! ollama pull "${APEX_OLLAMA_TAG}"; then
        fail "APEX 모델 다운로드 실패: ${APEX_OLLAMA_TAG}"
        echo "  확인 사항:"
        echo "    1. 모델명이 올바른지 확인: ollama search apex"
        echo "    2. APEX_MODEL_NAME 환경변수를 올바른 모델명으로 수정"
        echo "    3. 네트워크 연결 상태 확인"
        exit 1
    fi
    ok "APEX I-Compact 모델 다운로드 완료"
fi

# --------------------------------------------------
# 단계 3: Kanana-2-30B 모델 다운로드
# --------------------------------------------------
info "[3/8] Kanana-2-30B 모델을 다운로드한다: ${KANANA_OLLAMA_TAG}"
echo "  ※ 모델 파일이 크므로 시간이 소요될 수 있다."
echo "  ※ 모델명이 올바르지 않으면 .env 파일의 KANANA_MODEL_NAME을 수정하세요."
echo ""

if ollama list 2>/dev/null | grep -q "^${KANANA_OLLAMA_TAG}"; then
    ok "Kanana 모델이 이미 등록되어 있다. 다운로드를 건너뛴다."
else
    if ! ollama pull "${KANANA_OLLAMA_TAG}"; then
        fail "Kanana 모델 다운로드 실패: ${KANANA_OLLAMA_TAG}"
        echo "  확인 사항:"
        echo "    1. 모델명이 올바른지 확인: ollama search kanana"
        echo "    2. KANANA_MODEL_NAME 환경변수를 올바른 모델명으로 수정"
        echo "    3. 네트워크 연결 상태 확인"
        exit 1
    fi
    ok "Kanana-2-30B 모델 다운로드 완료"
fi

# --------------------------------------------------
# 단계 4: 등록된 모델 목록 확인
# --------------------------------------------------
info "[4/8] 등록된 Ollama 모델 목록을 확인한다..."
echo ""
ollama list
echo ""

# 두 모델이 모두 등록되었는지 교차 검증한다
MISSING_MODELS=()

if ! ollama list 2>/dev/null | grep -q "${APEX_OLLAMA_TAG}"; then
    MISSING_MODELS+=("${APEX_OLLAMA_TAG}")
fi
if ! ollama list 2>/dev/null | grep -q "${KANANA_OLLAMA_TAG}"; then
    MISSING_MODELS+=("${KANANA_OLLAMA_TAG}")
fi

if [ ${#MISSING_MODELS[@]} -gt 0 ]; then
    fail "다음 모델이 등록되지 않았다: ${MISSING_MODELS[*]}"
    exit 1
fi

ok "두 모델 모두 등록 확인 완료"

# --------------------------------------------------
# 단계 5: 각 모델 추론 테스트
# --------------------------------------------------
info "[5/8] 각 모델로 간단한 추론 테스트를 실행한다..."

TEST_PROMPT="Hello, respond with one word only."

echo "  APEX 모델 테스트 중..."
APEX_RESPONSE="$(ollama run "${APEX_OLLAMA_TAG}" "${TEST_PROMPT}" 2>&1 || true)"
if [ -z "${APEX_RESPONSE}" ]; then
    fail "APEX 모델 응답 없음"
    exit 1
fi
ok "APEX 응답 확인: ${APEX_RESPONSE:0:50}..."

echo "  Kanana 모델 테스트 중..."
KANANA_RESPONSE="$(ollama run "${KANANA_OLLAMA_TAG}" "${TEST_PROMPT}" 2>&1 || true)"
if [ -z "${KANANA_RESPONSE}" ]; then
    fail "Kanana 모델 응답 없음"
    exit 1
fi
ok "Kanana 응답 확인: ${KANANA_RESPONSE:0:50}..."

# --------------------------------------------------
# 단계 6: Python 의존성 설치 (uv sync)
# --------------------------------------------------
info "[6/8] Python 의존성을 설치한다 (uv sync)..."

if ! command -v uv &>/dev/null; then
    fail "uv 패키지 매니저가 설치되어 있지 않다."
    echo "  설치 방법: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

cd "${PROJECT_DIR}"
uv sync
ok "Python 의존성 설치 완료"

# --------------------------------------------------
# 단계 7: DB 마이그레이션 실행
# --------------------------------------------------
info "[7/8] 데이터베이스 스키마를 초기화한다..."

# DB 디렉토리가 없으면 생성한다
DB_DIR="$(eval echo "${DB_PATH:-~/.news-pulse}")"
mkdir -p "$(dirname "${DB_DIR}")"

if uv run python -m news_pulse.db.migrate; then
    ok "DB 마이그레이션 완료"
else
    fail "DB 마이그레이션 실패"
    echo "  backend-db 에이전트의 migrate 모듈이 구현되었는지 확인하세요."
    exit 1
fi

# --------------------------------------------------
# 단계 8: .env 파일 존재 확인
# --------------------------------------------------
info "[8/8] 환경변수 파일을 확인한다..."

if [ -f "${PROJECT_DIR}/.env" ]; then
    ok ".env 파일이 존재한다."
else
    fail ".env 파일이 없다."
    echo ""
    echo "  다음 명령으로 .env 파일을 생성하고 실제 값을 입력하세요:"
    echo "    cp '${PROJECT_DIR}/.env.example' '${PROJECT_DIR}/.env'"
    echo "    vim '${PROJECT_DIR}/.env'  # BOT_TOKEN, ADMIN_CHAT_ID 등 입력"
    echo ""
    exit 1
fi

# --------------------------------------------------
# 설정 완료 안내
# --------------------------------------------------
echo ""
echo "================================================================"
ok "news-pulse 초기 설정이 모두 완료되었다!"
echo ""
echo "  다음 단계:"
echo "    1. launchd 등록: bash scripts/install_launchd.sh"
echo "    2. 수동 실행 테스트: bash scripts/health_check.sh"
echo "    3. 봇 실행: uv run python -m news_pulse"
echo "================================================================"
echo ""
