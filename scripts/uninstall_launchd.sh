#!/bin/bash
# news-pulse launchd LaunchAgent 해제 스크립트
# launchctl로 언로드하고 ~/Library/LaunchAgents에서 plist 파일을 삭제한다.

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
PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_NAME}.plist"

echo ""
echo "================================================================"
echo "  news-pulse launchd 해제를 시작한다"
echo "================================================================"
echo ""

# --------------------------------------------------
# 단계 1: launchctl unload로 LaunchAgent 해제
# --------------------------------------------------
info "[1/3] launchd에서 LaunchAgent를 해제한다..."

if [ ! -f "${PLIST_PATH}" ]; then
    info "plist 파일이 없다. 이미 해제된 상태일 수 있다: ${PLIST_PATH}"
else
    # 실행 중인 작업이 있으면 먼저 중지한다 (오류 무시)
    launchctl stop "${PLIST_NAME}" 2>/dev/null || true

    if launchctl unload "${PLIST_PATH}" 2>/dev/null; then
        ok "LaunchAgent 언로드 완료"
    else
        info "언로드 중 경고 발생 (이미 해제 상태일 수 있다)"
    fi
fi

# --------------------------------------------------
# 단계 2: plist 파일 삭제
# --------------------------------------------------
info "[2/3] plist 파일을 삭제한다..."

if [ -f "${PLIST_PATH}" ]; then
    rm -f "${PLIST_PATH}"
    ok "plist 파일 삭제 완료: ${PLIST_PATH}"
else
    info "삭제할 plist 파일이 없다 (이미 삭제됨)"
fi

# --------------------------------------------------
# 단계 3: 해제 확인
# --------------------------------------------------
info "[3/3] 해제 상태를 확인한다..."

if launchctl list 2>/dev/null | grep -q "${PLIST_NAME}"; then
    fail "${PLIST_NAME}이 아직 launchd 목록에 남아있다."
    echo "  수동으로 확인하세요: launchctl list | grep news-pulse"
    exit 1
else
    ok "LaunchAgent가 목록에서 제거됨"
fi

# --------------------------------------------------
# 해제 완료 안내
# --------------------------------------------------
echo ""
echo "================================================================"
ok "news-pulse launchd 해제가 완료되었다!"
echo ""
echo "  ※ 로그 파일은 삭제되지 않았다:"
echo "    ${HOME}/.news-pulse/logs/"
echo ""
echo "  재등록 방법: bash scripts/install_launchd.sh"
echo "================================================================"
echo ""
