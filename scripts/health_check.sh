#!/bin/bash
# news-pulse 수동 헬스체크 실행 스크립트
# Flutter 앱에서 subprocess로 호출하거나 터미널에서 직접 실행한다.
# --health-check 플래그를 전달하여 봇 전체 실행 없이 상태만 확인한다.

set -euo pipefail

# --------------------------------------------------
# 색상 출력 정의
# --------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
fail() { echo -e "${RED}[실패]${NC} $*"; }
info() { echo -e "${YELLOW}[정보]${NC} $*"; }

# --------------------------------------------------
# 프로젝트 루트 경로 설정
# 스크립트 위치 기준으로 부모 디렉토리를 계산한다.
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 프로젝트 루트로 이동한다 (uv run이 pyproject.toml을 찾아야 함)
cd "${PROJECT_DIR}"

echo ""
info "news-pulse 헬스체크를 시작한다..."
echo ""

# --------------------------------------------------
# uv 존재 확인
# --------------------------------------------------
if ! command -v uv &>/dev/null; then
    fail "uv 패키지 매니저를 찾을 수 없다."
    echo "  설치 방법: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# --------------------------------------------------
# 헬스체크 실행
# --------------------------------------------------
if uv run python -m news_pulse --health-check; then
    ok "헬스체크 통과"
    exit 0
else
    EXIT_CODE=$?
    fail "헬스체크 실패 (종료 코드: ${EXIT_CODE})"
    echo ""
    echo "  확인 사항:"
    echo "    1. Ollama 서버 실행 중인지 확인: ollama serve"
    echo "    2. .env 파일 설정 확인: cat '${PROJECT_DIR}/.env'"
    echo "    3. 로그 확인: tail -50 ~/.news-pulse/logs/news_pulse.log"
    exit ${EXIT_CODE}
fi
