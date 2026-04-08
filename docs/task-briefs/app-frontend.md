# Task Brief: app-frontend

## 프로젝트 개요

news-pulse: 12개 IT/AI 소스에서 뉴스를 수집하고, 로컬 LLM으로 요약/번역 후 텔레그램으로 시간당 1회 푸시하는 macOS 전용 봇.
Flutter macOS 대시보드는 Python 백엔드와 **SQLite 파일을 직접 공유**하여 통신한다. 별도 API 서버 없음.

---

## 기술 스택

| 항목 | 버전/도구 |
|------|-----------|
| Flutter | 최신 stable |
| Dart | Flutter 번들 (3.x) |
| 플랫폼 | macOS only |
| 상태 관리 | Riverpod |
| DB 접근 | sqflite_common_ffi (SQLite direct access) |
| 차트 | fl_chart |
| URL 열기 | url_launcher |
| 프로세스 실행 | dart:io Process (헬스체크) |

---

## 담당 범위

1. Flutter macOS 프로젝트 초기화
2. 7개 화면 구현
3. SQLite 직접 읽기/쓰기 (WAL 모드)
4. Riverpod 상태 관리
5. 사이드바 네비게이션

---

## 생성할 파일 구조

```
news_pulse_app/                        # Flutter 프로젝트 루트
├── pubspec.yaml
├── macos/
│   └── (Flutter macOS 기본 설정)
├── lib/
│   ├── main.dart                      # 앱 엔트리포인트
│   ├── app.dart                       # MaterialApp + 라우팅
│   ├── core/
│   │   ├── database/
│   │   │   ├── database_helper.dart   # SQLite 연결 관리
│   │   │   └── tables.dart            # 테이블명/컬럼명 상수
│   │   ├── theme/
│   │   │   └── app_theme.dart         # 테마 정의
│   │   └── constants.dart             # 앱 전역 상수
│   ├── models/
│   │   ├── processed_item.dart
│   │   ├── hot_news.dart
│   │   ├── subscriber.dart
│   │   ├── run_history.dart
│   │   ├── error_log.dart
│   │   ├── filter_config.dart
│   │   └── health_check_result.dart
│   ├── repositories/
│   │   ├── news_repository.dart       # processed_items + hot_news
│   │   ├── subscriber_repository.dart # subscribers
│   │   ├── run_repository.dart        # run_history
│   │   ├── error_repository.dart      # error_log
│   │   ├── config_repository.dart     # filter_config
│   │   └── health_repository.dart     # health_check_results
│   ├── providers/
│   │   ├── database_provider.dart     # DB 인스턴스 Provider
│   │   ├── news_provider.dart
│   │   ├── subscriber_provider.dart
│   │   ├── run_provider.dart
│   │   ├── error_provider.dart
│   │   ├── config_provider.dart
│   │   └── health_provider.dart
│   ├── screens/
│   │   ├── home/
│   │   │   ├── home_screen.dart       # 화면 1: 홈
│   │   │   └── widgets/
│   │   │       ├── status_card.dart
│   │   │       ├── today_count_card.dart
│   │   │       ├── recent_errors_card.dart
│   │   │       └── subscriber_count_card.dart
│   │   ├── news/
│   │   │   ├── news_screen.dart       # 화면 2: 날짜별 뉴스
│   │   │   └── widgets/
│   │   │       ├── news_list_tile.dart
│   │   │       ├── hot_news_badge.dart
│   │   │       └── news_detail_dialog.dart
│   │   ├── subscribers/
│   │   │   ├── subscribers_screen.dart  # 화면 3: 구독자 관리
│   │   │   └── widgets/
│   │   │       ├── subscriber_tile.dart
│   │   │       └── subscriber_search.dart
│   │   ├── history/
│   │   │   ├── history_screen.dart    # 화면 4: 실행 이력
│   │   │   └── widgets/
│   │   │       └── run_detail_tile.dart
│   │   ├── errors/
│   │   │   ├── errors_screen.dart     # 화면 5: 오류 로그 + 헬스체크
│   │   │   └── widgets/
│   │   │       ├── error_list_tile.dart
│   │   │       └── health_check_panel.dart
│   │   ├── stats/
│   │   │   ├── stats_screen.dart      # 화면 6: 통계 대시보드
│   │   │   └── widgets/
│   │   │       ├── source_chart.dart
│   │   │       ├── pipeline_chart.dart
│   │   │       └── duration_chart.dart
│   │   └── settings/
│   │       ├── settings_screen.dart   # 화면 7: 설정
│   │       └── widgets/
│   │           ├── source_toggle_tile.dart
│   │           └── threshold_slider.dart
│   └── widgets/
│       ├── sidebar.dart               # 사이드바 네비게이션
│       └── scaffold_with_sidebar.dart
└── test/
    ├── repositories/
    │   └── news_repository_test.dart
    └── screens/
        └── home_screen_test.dart
```

---

## SQLite 연결 방식

### DB 경로

Python 백엔드와 같은 DB 파일 공유: `~/.news-pulse/news_pulse.db`
(경로는 환경변수 또는 앱 설정에서 읽되, 기본값으로 위 경로 사용)

### DatabaseHelper (core/database/database_helper.dart)

```dart
class DatabaseHelper {
  static Database? _database;

  /// SQLite 연결 (WAL 모드, FK 활성화)
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = '${Platform.environment['HOME']}/.news-pulse/news_pulse.db';
    final db = await databaseFactoryFfi.openDatabase(dbPath);
    // PRAGMA 설정은 Python 백엔드가 이미 처리함
    // 읽기 전용 연결에서는 추가 PRAGMA 불필요
    return db;
  }
}
```

**주의**: WAL 모드에서 Python(쓰기)과 Flutter(읽기+일부쓰기)가 동시 접근 가능.
Flutter의 쓰기 작업: 구독자 승인/거부, 핫뉴스 토글, 설정 변경.

---

## 7개 테이블 스키마 참조

Flutter에서 접근하는 테이블과 사용 방식:

| 테이블 | 화면 | 접근 방식 |
|--------|------|----------|
| processed_items | 1, 2, 6 | R (읽기) + 2에서 is_hot UPDATE |
| hot_news | 2 | RW (읽기 + INSERT/DELETE) |
| subscribers | 1, 3 | RW (읽기 + status UPDATE/DELETE) |
| run_history | 1, 4, 6 | R (읽기 전용) |
| error_log | 1, 5 | R (읽기 전용) |
| filter_config | 7 | RW (읽기 + value UPDATE) |
| health_check_results | 5 | R (읽기 전용, Python subprocess가 쓰기) |

### 테이블별 컬럼 상세 (models/ 에서 매핑)

#### processed_items

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | INTEGER PK | 고유 식별자 |
| url_hash | TEXT UNIQUE NN | SHA-256 해시 |
| url | TEXT NN | 원문 URL |
| title | TEXT NN | 기사 제목 |
| source | TEXT NN | 소스명 |
| language | TEXT NN | 언어 코드 (ko/en) |
| raw_content | TEXT | 원본 콘텐츠 |
| summary_ko | TEXT | 한국어 요약 |
| tags | TEXT | 태그 (JSON 배열 문자열) |
| upvotes | INTEGER (0) | 업보트 수 |
| is_hot | INTEGER (0) | 핫뉴스 여부 |
| pipeline_path | TEXT | 파이프라인 경로 (apex/kanana/claude) |
| processing_time_ms | INTEGER | 처리 소요시간 |
| telegram_sent | INTEGER (0) | 전송 여부 |
| created_at | TEXT NN | 생성 시각 |

#### hot_news

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | INTEGER PK | 고유 식별자 |
| processed_item_id | INTEGER FK NN | processed_items.id 참조 |
| url | TEXT NN | 원문 URL |
| title | TEXT NN | 기사 제목 |
| source | TEXT NN | 소스명 |
| summary_ko | TEXT NN | 한국어 요약 |
| tags | TEXT | 태그 |
| upvotes | INTEGER (0) | 업보트 수 |
| hot_reason | TEXT NN | 판단 이유 (upvote_auto/source_auto/manual) |
| created_at | TEXT NN | 생성 시각 |

#### subscribers

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | INTEGER PK | 고유 식별자 |
| chat_id | INTEGER UNIQUE NN | 텔레그램 chat_id |
| username | TEXT | 텔레그램 username |
| first_name | TEXT | 텔레그램 이름 |
| status | TEXT NN ('pending') | pending/approved/rejected |
| requested_at | TEXT NN | 신청 시각 |
| approved_at | TEXT | 승인 시각 |
| rejected_at | TEXT | 거부 시각 |
| is_admin | INTEGER (0) | 관리자 여부 |

#### run_history

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | INTEGER PK | 고유 식별자 |
| started_at | TEXT NN | 시작 시각 |
| finished_at | TEXT | 종료 시각 |
| status | TEXT NN | running/success/partial_failure/failure |
| fetched_count | INTEGER (0) | 수집 건수 |
| filtered_count | INTEGER (0) | 필터 통과 건수 |
| summarized_count | INTEGER (0) | 요약 완료 건수 |
| sent_count | INTEGER (0) | 전송 건수 |
| total_duration_ms | INTEGER | 총 소요 시간 |
| model_load_ms | INTEGER | 모델 로드 시간 |
| inference_ms | INTEGER | 추론 시간 |
| memory_mode | TEXT | local_llm/claude_fallback |
| error_message | TEXT | 에러 메시지 |

#### error_log

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | INTEGER PK | 고유 식별자 |
| run_id | INTEGER FK (nullable) | run_history.id 참조 |
| severity | TEXT NN | info/warning/error/critical |
| module | TEXT NN | 에러 발생 모듈명 |
| message | TEXT NN | 에러 메시지 |
| traceback | TEXT | 스택 트레이스 |
| created_at | TEXT NN | 에러 시각 |

#### filter_config

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | INTEGER PK | 고유 식별자 |
| key | TEXT UNIQUE NN | 설정 키 |
| value | TEXT NN | 설정 값 |
| description | TEXT | 설명 |
| updated_at | TEXT NN | 마지막 수정 시각 |

#### health_check_results

| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | INTEGER PK | 고유 식별자 |
| check_type | TEXT NN | ollama/source/telegram/db/disk |
| target | TEXT NN | 체크 대상 |
| status | TEXT NN | ok/warning/error |
| message | TEXT | 상태 메시지 |
| response_time_ms | INTEGER | 응답 시간 |
| created_at | TEXT NN | 체크 시각 |

---

## 화면 상세 스펙

### 화면 1: 홈 (Overview)

**파일**: `screens/home/home_screen.dart`
**데이터 흐름**: run_history(R), processed_items(R), error_log(R), subscribers(R)

**기능**:
1. **봇 상태 카드**: 마지막 실행 시각 + 성공/실패 상태
   - `SELECT * FROM run_history ORDER BY started_at DESC LIMIT 1`
2. **오늘 전송 건수 카드**: 오늘 날짜의 telegram_sent=1 건수
   - `SELECT COUNT(*) FROM processed_items WHERE telegram_sent=1 AND date(created_at)=date('now','localtime')`
3. **최근 에러 요약 카드**: 최근 N건 에러
   - `SELECT * FROM error_log ORDER BY created_at DESC LIMIT 5`
4. **다음 실행 시간**: launchd 스케줄 기반 코드 로직으로 계산 (09:00~00:00 매시)
5. **구독자 수 카드**: pending/approved 각각 COUNT
   - `SELECT status, COUNT(*) FROM subscribers GROUP BY status`

**레이아웃**: 카드 그리드 (2열)

---

### 화면 2: 날짜별 뉴스

**파일**: `screens/news/news_screen.dart`
**데이터 흐름**: processed_items(RW), hot_news(RW)

**기능**:
1. **날짜 선택**: 30일 범위 날짜 피커
2. **일반 뉴스 / 핫뉴스 탭**: 탭으로 분리
   - 일반: `SELECT * FROM processed_items WHERE date(created_at)=? ORDER BY created_at DESC`
   - 핫: `SELECT * FROM hot_news ORDER BY created_at DESC`
3. **뉴스 상세 다이얼로그**: 제목, 요약, 태그, 원문 링크, 파이프라인 경로, 소요 시간
4. **핫뉴스 수동 토글**: is_hot 업데이트 + hot_news INSERT/DELETE
   - 핫 지정: `UPDATE processed_items SET is_hot=1 WHERE id=?` + `INSERT INTO hot_news (...) VALUES (...)`
   - 핫 해제: `UPDATE processed_items SET is_hot=0 WHERE id=?` + `DELETE FROM hot_news WHERE processed_item_id=?`
5. **원문 링크 열기**: url_launcher로 브라우저 열기

---

### 화면 3: 구독자 관리

**파일**: `screens/subscribers/subscribers_screen.dart`
**데이터 흐름**: subscribers(RW)

**기능**:
1. **탭 분리**: pending / approved / rejected
   - `SELECT * FROM subscribers WHERE status=? ORDER BY requested_at DESC`
2. **검색**: username, chat_id로 필터
3. **승인 버튼**: `UPDATE subscribers SET status='approved', approved_at=datetime('now','localtime') WHERE chat_id=?`
4. **거부 버튼**: `UPDATE subscribers SET status='rejected', rejected_at=datetime('now','localtime') WHERE chat_id=?`
5. **삭제 버튼**: `DELETE FROM subscribers WHERE chat_id=?` (확인 다이얼로그 필수)
6. **구독자 상세**: 신청일, 승인일, is_admin 표시

---

### 화면 4: 실행 이력

**파일**: `screens/history/history_screen.dart`
**데이터 흐름**: run_history(R)

**기능**:
1. **실행 결과 리스트**: 시간순 내림차순
   - `SELECT * FROM run_history ORDER BY started_at DESC LIMIT 50`
2. **건수 표시**: fetched / filtered / summarized / sent
3. **소요 시간**: total_duration_ms, model_load_ms, inference_ms (밀리초 -> 초 변환)
4. **상태 표시**: 색상 코딩 (success=녹색, partial_failure=주황, failure=빨강)
5. **에러 메시지**: 실패 시 error_message 표시

---

### 화면 5: 오류 로그 + 헬스체크

**파일**: `screens/errors/errors_screen.dart`
**데이터 흐름**: error_log(R), health_check_results(R)

**기능**:
1. **[오류 로그 탭]** 시간순 에러 목록
   - `SELECT * FROM error_log ORDER BY created_at DESC LIMIT 50`
2. **심각도 필터**: info / warning / error / critical 드롭다운
   - `SELECT * FROM error_log WHERE severity=? ORDER BY created_at DESC`
3. **[헬스체크 탭]** 수동 실행 버튼
   - `Process.run()` 으로 Python 헬스체크 스크립트 실행:
     `uv run python -m news_pulse --health-check`
   - 실행 후 health_check_results 테이블에서 최신 결과 읽기
4. **헬스체크 결과**: check_type별 상태 리포트 (ok/warning/error 색상 코딩)
   - `SELECT * FROM health_check_results ORDER BY created_at DESC`

---

### 화면 6: 통계 대시보드

**파일**: `screens/stats/stats_screen.dart`
**데이터 흐름**: processed_items(R), run_history(R)

**기능**:
1. **소스별 건수 차트** (일별/주별):
   - `SELECT source, date(created_at) as d, COUNT(*) FROM processed_items WHERE created_at >= datetime('now','-7 days','localtime') GROUP BY source, d`
2. **파이프라인 성공률**:
   - `SELECT pipeline_path, COUNT(*) FROM processed_items WHERE pipeline_path IS NOT NULL GROUP BY pipeline_path`
3. **응답 시간 추이**:
   - `SELECT started_at, total_duration_ms, model_load_ms, inference_ms FROM run_history ORDER BY started_at DESC LIMIT 30`
4. **필터링 효율**: 수집 vs 통과 vs 전송 비율
   - `SELECT fetched_count, filtered_count, sent_count FROM run_history ORDER BY started_at DESC LIMIT 30`

**차트 라이브러리**: fl_chart (막대 차트, 라인 차트)

---

### 화면 7: 설정 (Settings)

**파일**: `screens/settings/settings_screen.dart`
**데이터 흐름**: filter_config(RW)

**기능**:
1. **소스 ON/OFF 토글** (12개):
   - `SELECT * FROM filter_config WHERE key LIKE 'source_%_enabled'`
   - 변경 시: `UPDATE filter_config SET value=?, updated_at=datetime('now','localtime') WHERE key=?`
2. **필터 임계값 조정**:
   - hn_min_points, hn_young_min_points
   - reddit_localllama_min_upvotes, reddit_claudeai_min_upvotes, reddit_cursor_min_upvotes
3. **MAX_ITEMS_PER_RUN 조정**: 슬라이더 (1~20)
4. **ALLOW_TIER1_OVERFLOW 토글**: 스위치

**filter_config 시드 키 목록** (19개):

| key | 설명 | UI 위젯 |
|-----|------|---------|
| source_geeknews_enabled | GeekNews 활성화 | Switch |
| source_hackernews_enabled | Hacker News 활성화 | Switch |
| source_reddit_localllama_enabled | r/LocalLLaMA 활성화 | Switch |
| source_reddit_claudeai_enabled | r/ClaudeAI 활성화 | Switch |
| source_reddit_cursor_enabled | r/Cursor 활성화 | Switch |
| source_anthropic_enabled | Anthropic 활성화 | Switch |
| source_openai_enabled | OpenAI 활성화 | Switch |
| source_deepmind_enabled | DeepMind 활성화 | Switch |
| source_huggingface_enabled | HuggingFace 활성화 | Switch |
| source_claude_code_enabled | Claude Code 활성화 | Switch |
| source_cline_enabled | Cline 활성화 | Switch |
| source_cursor_changelog_enabled | Cursor Changelog 활성화 | Switch |
| hn_min_points | HN 최소 업보트 | Slider/TextField |
| hn_young_min_points | HN 최소 업보트 (2h 미만) | Slider/TextField |
| reddit_localllama_min_upvotes | LocalLLaMA 최소 업보트 | Slider/TextField |
| reddit_claudeai_min_upvotes | ClaudeAI 최소 업보트 | Slider/TextField |
| reddit_cursor_min_upvotes | Cursor 최소 업보트 | Slider/TextField |
| max_items_per_run | 시간당 최대 전송 | Slider |
| allow_tier1_overflow | Tier1 초과 허용 | Switch |

---

## 네비게이션 구조

사이드바 네비게이션 (macOS 스타일):

```
[사이드바]                    [메인 컨텐츠]
 1. 홈                       ┌──────────────────┐
 2. 날짜별 뉴스               │                  │
 3. 구독자 관리               │  선택된 화면 표시  │
 4. 실행 이력                 │                  │
 5. 오류/헬스체크              │                  │
 6. 통계                     │                  │
 7. 설정                     └──────────────────┘
```

NavigationRail 또는 커스텀 사이드바 위젯 사용.

---

## Riverpod Provider 구조

```
DatabaseProvider (DB 인스턴스)
  ├── NewsProvider (processed_items + hot_news 쿼리)
  ├── SubscriberProvider (subscribers 쿼리)
  ├── RunProvider (run_history 쿼리)
  ├── ErrorProvider (error_log 쿼리)
  ├── ConfigProvider (filter_config 쿼리)
  └── HealthProvider (health_check_results 쿼리)
```

각 Provider는 해당 Repository를 래핑하여 상태를 관리한다.
자동 새로고침: Timer로 주기적 DB 폴링 (30초 간격) 또는 수동 새로고침 버튼.

---

## 디자인 가이드

macOS 네이티브 스타일을 기반으로 한 깔끔한 대시보드.

- 밝은 배경 (#F4F3EE 또는 시스템 기본)
- 카드 기반 레이아웃
- 상태별 색상: success=녹색, warning=주황, error=빨강
- 모노스페이스 폰트: 코드/해시/ID 표시 시
- macOS 창 크기: 최소 1000x700
- 사이드바 너비: 200~220px

---

## 의존성

### pubspec.yaml 패키지

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.0.0
  sqflite_common_ffi: ^2.0.0
  fl_chart: ^0.65.0
  url_launcher: ^6.0.0
  intl: ^0.18.0          # 날짜 포맷팅
  path_provider: ^2.0.0   # 앱 데이터 경로
  path: ^1.8.0
```

### 다른 에이전트와의 접점

- **backend-db**: 같은 SQLite 파일 공유. 테이블 스키마/컬럼명이 정확히 일치해야 함
- **backend-api**: HealthChecker를 subprocess로 호출 (`python -m news_pulse --health-check`)
- **devops-engineer**: 없음

### 선행 조건

- **backend-db가 먼저 완료**되어야 함 (테이블 스키마가 확정되어야 모델/쿼리 작성 가능)
- DB 파일 경로: `~/.news-pulse/news_pulse.db` (backend-db가 생성)

---

## macOS 권한 설정

`macos/Runner/DebugProfile.entitlements` 및 `Release.entitlements`에 추가:

```xml
<key>com.apple.security.network.client</key>
<true/>
<!-- 외부 URL 열기 위해 필요 -->
```

파일 시스템 접근 (SQLite): macOS 샌드박스에서 `~/.news-pulse/` 접근을 위해 다음 중 하나:
- 샌드박스 비활성화 (개인 사용이므로 권장)
- 또는 파일 북마크 사용

---

## 코딩 규칙

1. 모든 주석은 한국어로 작성
2. camelCase 변수/함수명 (Dart 관례)
3. 파일당 최대 200줄
4. 위젯당 최대 150줄 (초과 시 분리)
5. const 생성자 적극 활용
6. 비즈니스 로직은 Repository/Provider에만 (화면에서 직접 SQL 금지)
7. 모든 SQL 쿼리는 Repository 레이어에 집중

---

## 테스트 요구사항

1. Repository 단위 테스트 (인메모리 SQLite)
2. 화면 위젯 테스트 (mock Provider)
3. 핫뉴스 토글 통합 테스트 (processed_items + hot_news 연동)
4. filter_config 읽기/쓰기 테스트

---

## Checkpoint Protocol

각 화면 완료 후:
1. 이 brief의 해당 화면 스펙을 다시 읽는다
2. 구현된 데이터 흐름 방향(R/W/RW)이 스펙과 일치하는지 검증한다
3. SQL 쿼리가 테이블 스키마와 일치하는지 확인한다
4. 다음 화면으로 진행한다
5. 이 brief에 없는 화면은 절대 구현하지 않는다
