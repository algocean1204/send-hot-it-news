"""
블럭 1 — ConfigLoader.

.env 파일을 읽어 Config 객체를 생성한다.
필수 환경변수 검증 + TZ 이중 고정까지 담당한다.
filter_config에서 커스텀 소스 및 다이제스트 설정도 로드한다.
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Protocol

from dotenv import load_dotenv

from news_pulse.db.store import SqliteStore
from news_pulse.models.config import Config, SourceConfig

# 기본 소스 목록 — filter_config에 재정의 없을 때 사용
_DEFAULT_SOURCES: list[dict[str, object]] = [
    {"source_id": "geeknews", "name": "GeekNews", "url": "https://news.hada.io/rss",
     "source_type": "rss", "tier": 2, "language": "ko"},
    {"source_id": "hackernews", "name": "Hacker News",
     "url": "http://hn.algolia.com/api/v1/search",
     "source_type": "algolia", "tier": 3, "language": "en"},
    {"source_id": "reddit_localllama", "name": "r/LocalLLaMA",
     "url": "https://www.reddit.com/r/LocalLLaMA/hot.json",
     "source_type": "reddit", "tier": 3, "language": "en"},
    {"source_id": "reddit_claudeai", "name": "r/ClaudeAI",
     "url": "https://www.reddit.com/r/ClaudeAI/hot.json",
     "source_type": "reddit", "tier": 3, "language": "en"},
    {"source_id": "reddit_cursor", "name": "r/cursor",
     "url": "https://www.reddit.com/r/cursor/hot.json",
     "source_type": "reddit", "tier": 3, "language": "en"},
    {"source_id": "anthropic", "name": "Anthropic Blog",
     "url": "https://www.anthropic.com/rss.xml",
     "source_type": "rss", "tier": 1, "language": "en"},
    {"source_id": "openai", "name": "OpenAI Blog",
     "url": "https://openai.com/blog/rss.xml",
     "source_type": "rss", "tier": 1, "language": "en"},
    {"source_id": "deepmind", "name": "DeepMind Blog",
     "url": "https://deepmind.google/blog/rss.xml",
     "source_type": "rss", "tier": 1, "language": "en"},
    {"source_id": "huggingface", "name": "HuggingFace Blog",
     "url": "https://huggingface.co/blog/feed.xml",
     "source_type": "rss", "tier": 1, "language": "en"},
    {"source_id": "claude_code_releases", "name": "Claude Code Releases",
     "url": "https://github.com/anthropics/claude-code/releases.atom",
     "source_type": "github_atom", "tier": 1, "language": "en"},
    {"source_id": "cline_releases", "name": "Cline Releases",
     "url": "https://github.com/cline/cline/releases.atom",
     "source_type": "github_atom", "tier": 1, "language": "en"},
    {"source_id": "cursor_changelog", "name": "Cursor Changelog",
     "url": "https://changelog.cursor.com/rss",
     "source_type": "rss", "tier": 1, "language": "en"},
]

# 필수 환경변수 목록 — 하나라도 빠지면 즉시 ValueError
_REQUIRED_KEYS: list[str] = ["BOT_TOKEN", "ADMIN_CHAT_ID", "DB_PATH"]


class ConfigLoaderProtocol(Protocol):
    """ConfigLoader 인터페이스 정의."""

    def load(self) -> Config: ...


class EnvConfigLoader:
    """
    .env 파일에서 Config를 생성하는 구현체.

    filter_config 테이블에서 소스 ON/OFF, 필터 임계값을 추가로 읽는다.
    """

    def __init__(self, env_path: str = ".env", db: SqliteStore | None = None) -> None:
        """
        env_path: .env 파일 경로 (절대/상대 모두 가능).
        db: filter_config 읽기용 SqliteStore (None이면 DB 읽기 생략).
        """
        self._env_path = env_path
        self._db = db

    def load(self) -> Config:
        """환경변수 파싱 -> TZ 고정 -> Config 생성."""
        load_dotenv(dotenv_path=self._env_path, override=True)
        self._validate_required_keys()
        self._fix_timezone()

        db_path = os.path.expanduser(os.environ["DB_PATH"])
        config = Config(
            bot_token=os.environ["BOT_TOKEN"],
            admin_chat_id=os.environ["ADMIN_CHAT_ID"],
            db_path=db_path,
            ollama_endpoint=os.environ.get("OLLAMA_ENDPOINT", "http://localhost:11434"),
            apex_model_name=os.environ.get("APEX_MODEL_NAME", "apex-i-compact"),
            kanana_model_name=os.environ.get("KANANA_MODEL_NAME", "kanana-2-30b"),
            memory_threshold_gb=float(os.environ.get("MEMORY_THRESHOLD_GB", "26.0")),
            sources=self._build_sources(),
        )
        if self._db is not None:
            self._apply_filter_config(config)
        return config

    def _validate_required_keys(self) -> None:
        """필수 키 누락 또는 빈 문자열 시 ValueError를 발생시킨다."""
        for key in _REQUIRED_KEYS:
            val = os.environ.get(key, "")
            if not val.strip():
                raise ValueError(f"필수 환경변수 누락 또는 빈 값: {key}")

    def _fix_timezone(self) -> None:
        """TZ를 Asia/Seoul로 이중 고정한다 (os.environ + tzset)."""
        os.environ["TZ"] = "Asia/Seoul"
        if hasattr(time, "tzset"):
            time.tzset()

    def _build_sources(self) -> list[SourceConfig]:
        """기본 소스 목록을 SourceConfig 리스트로 변환한다."""
        return [
            SourceConfig(
                source_id=str(s["source_id"]),
                name=str(s["name"]),
                url=str(s["url"]),
                source_type=str(s["source_type"]),
                # tier는 int로 선언된 dict value — str() 경유 없이 안전하게 변환
                tier=int(str(s["tier"])),
                language=str(s["language"]),
                enabled=True,
            )
            for s in _DEFAULT_SOURCES
        ]

    def _apply_filter_config(self, config: Config) -> None:
        """filter_config 테이블에서 소스 ON/OFF, 임계값을 읽어 Config를 갱신한다."""
        assert self._db is not None
        all_cfg = self._db.get_all_config()

        # 소스 ON/OFF 갱신 — Flutter는 '1'/'0', seed.sql은 'true'/'false' 모두 허용
        for source in config.sources:
            key = f"source_{source.source_id}_enabled"
            if key in all_cfg:
                source.enabled = all_cfg[key].lower() in ("true", "1")

        # 필터 임계값 갱신
        if "tier3_hn_threshold" in all_cfg:
            config.tier3_hn_threshold = int(all_cfg["tier3_hn_threshold"])
        if "tier3_reddit_threshold" in all_cfg:
            config.tier3_reddit_threshold = int(all_cfg["tier3_reddit_threshold"])
        if "blacklist_keywords" in all_cfg:
            raw = all_cfg["blacklist_keywords"].strip()
            config.blacklist_keywords = [k.strip() for k in raw.split(",") if k.strip()]
        # 다이제스트 모드 설정 갱신 (F07)
        if "digest_enabled" in all_cfg:
            config.digest_enabled = all_cfg["digest_enabled"].lower() in ("true", "1")
        if "digest_hour" in all_cfg:
            config.digest_hour = int(all_cfg["digest_hour"])
        # 커스텀 소스 추가 (F12) — JSON 배열 문자열로 저장된 custom_sources를 병합
        if "custom_sources" in all_cfg:
            self._merge_custom_sources(config, all_cfg["custom_sources"])

    def _merge_custom_sources(self, config: Config, raw_json: str) -> None:
        """filter_config의 custom_sources JSON을 파싱해 config.sources에 병합한다."""
        try:
            sources_data: list[dict[str, object]] = json.loads(raw_json)
            for s in sources_data:
                custom = SourceConfig(
                    source_id=str(s.get("source_id", "")),
                    name=str(s.get("name", "")),
                    url=str(s.get("url", "")),
                    source_type=str(s.get("source_type", "rss")),
                    tier=int(str(s.get("tier", 3))),
                    language=str(s.get("language", "en")),
                    enabled=bool(s.get("enabled", True)),
                    is_custom=True,
                )
                # 동일 source_id가 이미 있으면 덮어쓰지 않고 새로 추가
                existing_ids = {src.source_id for src in config.sources}
                if custom.source_id and custom.source_id not in existing_ids:
                    config.sources.append(custom)
        except (json.JSONDecodeError, ValueError) as exc:
            import logging
            logging.getLogger(__name__).warning("custom_sources 파싱 실패: %s", exc)
