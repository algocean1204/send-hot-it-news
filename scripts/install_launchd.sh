#!/bin/bash
# news-pulse launchd LaunchAgent 등록 스크립트
# plist 파일을 ~/Library/LaunchAgents/에 복사하고 launchctl로 등록한다.

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
# 경로 설정
# --------------------------------------------------
PLIST_NAME="com.news-pulse.bot"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLIST_SRC="${PROJECT_DIR}/launchd/${PLIST_NAME}.plist"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_DST="${LAUNCH_AGENTS_DIR}/${PLIST_NAME}.plist"
# 로그 파일 저장 경로
LOG_DIR="${HOME}/.news-pulse/logs"

echo ""
echo "================================================================"
echo "  news-pulse launchd 등록을 시작한다"
echo "================================================================"
echo ""

# --------------------------------------------------
# 단계 1: uv 경로 확인
# --------------------------------------------------
info "[1/5] uv 경로를 확인한다..."

if ! UV_PATH="$(command -v uv 2>/dev/null)"; then
    fail "uv 패키지 매니저를 찾을 수 없다."
    echo "  설치 방법: curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "  설치 후 셸을 재시작하거나 'source ~/.zshrc'를 실행하세요."
    exit 1
fi

ok "uv 경로 확인: ${UV_PATH}"

# --------------------------------------------------
# 단계 2: 원본 plist 파일 존재 확인
# --------------------------------------------------
info "[2/5] 원본 plist 파일을 확인한다..."

if [ ! -f "${PLIST_SRC}" ]; then
    fail "plist 파일이 없다: ${PLIST_SRC}"
    exit 1
fi

ok "원본 plist 파일 확인: ${PLIST_SRC}"

# --------------------------------------------------
# 단계 3: plist 파일 복사 및 경로 치환
# --------------------------------------------------
info "[3/5] plist 파일을 복사하고 실제 경로로 치환한다..."

# ~/Library/LaunchAgents 디렉토리가 없으면 생성한다
mkdir -p "${LAUNCH_AGENTS_DIR}"

# 로그 디렉토리 생성
mkdir -p "${LOG_DIR}"

# 임시 파일에 복사 후 경로 치환 (원본 plist의 placeholder를 실제 값으로 교체)
TEMP_PLIST="$(mktemp /tmp/${PLIST_NAME}.XXXXXX.plist)"

# sed로 placeholder 문자열을 실제 경로로 치환한다
sed \
    -e "s|/path/to/uv|${UV_PATH}|g" \
    -e "s|/path/to/news-pulse|${PROJECT_DIR}|g" \
    -e "s|/tmp/news-pulse-stdout.log|${LOG_DIR}/stdout.log|g" \
    -e "s|/tmp/news-pulse-stderr.log|${LOG_DIR}/stderr.log|g" \
    "${PLIST_SRC}" > "${TEMP_PLIST}"

# 치환 결과를 대상 경로에 복사한다
cp "${TEMP_PLIST}" "${PLIST_DST}"
rm -f "${TEMP_PLIST}"

ok "plist 복사 완료: ${PLIST_DST}"
info "  uv 경로: ${UV_PATH}"
info "  프로젝트 경로: ${PROJECT_DIR}"
info "  로그 경로: ${LOG_DIR}"

# --------------------------------------------------
# plist XML 유효성 검증
# --------------------------------------------------
info "  plist XML 유효성 검증 중..."
if ! plutil -lint "${PLIST_DST}" &>/dev/null; then
    fail "plist XML 유효성 검증 실패"
    plutil -lint "${PLIST_DST}"
    rm -f "${PLIST_DST}"
    exit 1
fi
ok "plist XML 유효성 검증 통과"

# --------------------------------------------------
# 단계 4: launchctl load로 LaunchAgent 등록
# --------------------------------------------------
info "[4/5] launchd에 LaunchAgent를 등록한다..."

# 이미 등록된 경우 먼저 해제한다 (오류 무시)
launchctl unload "${PLIST_DST}" 2>/dev/null || true

if launchctl load "${PLIST_DST}"; then
    ok "LaunchAgent 등록 완료"
else
    fail "LaunchAgent 등록 실패"
    echo "  plist 파일 내용을 확인하세요: ${PLIST_DST}"
    exit 1
fi

# --------------------------------------------------
# 단계 5: 등록 확인
# --------------------------------------------------
info "[5/5] 등록 상태를 확인한다..."

if launchctl list | grep -q "${PLIST_NAME}"; then
    ok "LaunchAgent 등록 확인됨"
    echo ""
    launchctl list "${PLIST_NAME}" 2>/dev/null || true
else
    fail "LaunchAgent 목록에서 ${PLIST_NAME}을 찾을 수 없다."
    echo "  'launchctl list' 명령으로 수동 확인하세요."
    exit 1
fi

# --------------------------------------------------
# 등록 완료 안내
# --------------------------------------------------
echo ""
echo "================================================================"
ok "news-pulse launchd 등록이 완료되었다!"
echo ""
echo "  스케줄: 매일 09:00 ~ 00:00 (매시 정각, 16회/일)"
echo "  로그:"
echo "    표준 출력: ${LOG_DIR}/stdout.log"
echo "    표준 오류: ${LOG_DIR}/stderr.log"
echo ""
echo "  유용한 명령:"
echo "    수동 실행: launchctl start ${PLIST_NAME}"
echo "    수동 중지: launchctl stop ${PLIST_NAME}"
echo "    해제:      bash '${SCRIPT_DIR}/uninstall_launchd.sh'"
echo "    헬스체크:  bash '${SCRIPT_DIR}/health_check.sh'"
echo "================================================================"
echo ""
