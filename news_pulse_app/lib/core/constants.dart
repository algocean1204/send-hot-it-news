import 'dart:io';

// ============================================================
// 앱 전역 상수
// ============================================================

/// SQLite DB 기본 경로 — Python 백엔드와 동일한 경로를 사용한다
final String kDefaultDbPath =
    '${Platform.environment['HOME']}/.news-pulse/news_pulse.db';

/// 사이드바 너비
const double kSidebarWidth = 210.0;

/// 앱 최소 창 크기
const double kMinWindowWidth = 1000.0;
const double kMinWindowHeight = 700.0;

/// DB 자동 폴링 주기 (초)
const int kPollingIntervalSeconds = 30;

/// 최근 에러 조회 최대 건수 (홈 화면)
const int kRecentErrorsLimit = 5;

/// 실행 이력 조회 최대 건수
const int kRunHistoryLimit = 50;

/// 에러 로그 조회 최대 건수
const int kErrorLogLimit = 50;

/// 통계 차트 최근 실행 건수
const int kStatsRunLimit = 30;

/// launchd 스케줄 시작/종료 시간 (매시 실행: 09:00 ~ 00:00)
const int kScheduleStartHour = 9;
const int kScheduleEndHour = 24; // 자정 포함
