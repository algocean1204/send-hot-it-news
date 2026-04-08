"""
ConfigLoader 단위 테스트.

필수 키 누락 시 ValueError, 정상 로드 시 Config 반환을 검증한다.
"""
from __future__ import annotations

import os

import pytest

from news_pulse.blocks.config_loader import EnvConfigLoader


def test_missing_bot_token_raises(tmp_path: pytest.TempPathFactory) -> None:
    """BOT_TOKEN이 없으면 ValueError가 발생해야 한다."""
    env_file = tmp_path / ".env"
    env_file.write_text("ADMIN_CHAT_ID=123\nDB_PATH=/tmp/test.db\n")
    # 환경변수를 비워서 누락 시뮬레이션
    env_vars = {"BOT_TOKEN": "", "ADMIN_CHAT_ID": "123", "DB_PATH": "/tmp/test.db"}
    for k, v in env_vars.items():
        os.environ[k] = v
    os.environ.pop("BOT_TOKEN", None)

    loader = EnvConfigLoader(env_path=str(env_file))
    with pytest.raises(ValueError, match="BOT_TOKEN"):
        loader.load()


def test_missing_admin_chat_id_raises(tmp_path: pytest.TempPathFactory) -> None:
    """ADMIN_CHAT_ID가 없으면 ValueError가 발생해야 한다."""
    env_file = tmp_path / ".env"
    env_file.write_text("BOT_TOKEN=tok\nDB_PATH=/tmp/test.db\n")
    os.environ["BOT_TOKEN"] = "tok"
    os.environ.pop("ADMIN_CHAT_ID", None)
    os.environ["DB_PATH"] = "/tmp/test.db"

    loader = EnvConfigLoader(env_path=str(env_file))
    with pytest.raises(ValueError, match="ADMIN_CHAT_ID"):
        loader.load()


def test_empty_bot_token_raises(tmp_path: pytest.TempPathFactory) -> None:
    """BOT_TOKEN이 빈 문자열이면 ValueError가 발생해야 한다."""
    env_file = tmp_path / ".env"
    env_file.write_text("BOT_TOKEN=\nADMIN_CHAT_ID=123\nDB_PATH=/tmp/test.db\n")

    loader = EnvConfigLoader(env_path=str(env_file))
    with pytest.raises(ValueError, match="BOT_TOKEN"):
        loader.load()


def test_valid_env_returns_config(tmp_path: pytest.TempPathFactory) -> None:
    """정상적인 .env 파일로 Config 객체가 반환되어야 한다."""
    env_file = tmp_path / ".env"
    env_file.write_text(
        "BOT_TOKEN=mytoken\n"
        "ADMIN_CHAT_ID=99999\n"
        "DB_PATH=/tmp/test_np.db\n"
        "MEMORY_THRESHOLD_GB=16.0\n"
    )
    loader = EnvConfigLoader(env_path=str(env_file))
    config = loader.load()

    assert config.bot_token == "mytoken"
    assert config.admin_chat_id == "99999"
    assert config.memory_threshold_gb == 16.0
    assert len(config.sources) == 12


def test_sources_count_is_twelve(tmp_path: pytest.TempPathFactory) -> None:
    """기본 소스 목록은 12개여야 한다."""
    env_file = tmp_path / ".env"
    env_file.write_text("BOT_TOKEN=tok\nADMIN_CHAT_ID=1\nDB_PATH=/tmp/test2.db\n")
    loader = EnvConfigLoader(env_path=str(env_file))
    config = loader.load()
    assert len(config.sources) == 12
