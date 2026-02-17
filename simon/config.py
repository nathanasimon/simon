"""Configuration management for simon."""

import os
from pathlib import Path
from typing import Optional

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class GeneralSettings(BaseSettings):
    db_url: str = Field(default="postgresql+asyncpg://localhost/simon")
    log_level: str = "INFO"


class AnthropicSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="ANTHROPIC_")
    api_key: str = ""
    model: str = "claude-haiku-4-5-20251001"


class ContextSettings(BaseSettings):
    """Settings for the context recording and retrieval system."""

    enabled: bool = True
    retrieval_enabled: bool = True
    recording_enabled: bool = True
    retrieval_timeout_ms: int = 2000
    recording_timeout_ms: int = 200
    max_context_tokens: int = 1500
    turn_summary_model: str = "claude-haiku-4-5-20251001"
    session_summary_model: str = "claude-haiku-4-5-20251001"
    worker_poll_interval: float = 2.0


class SkillSettings(BaseSettings):
    """Settings for the skills system."""

    auto_generate: bool = True
    min_quality_score: float = 0.6
    default_scope: str = "personal"
    max_auto_skills_per_day: int = 3
    skill_generation_model: str = "claude-haiku-4-5-20251001"
    github_token: str = ""


class Settings(BaseSettings):
    """Top-level settings assembled from subsections."""

    general: GeneralSettings = Field(default_factory=GeneralSettings)
    anthropic: AnthropicSettings = Field(default_factory=AnthropicSettings)
    context: ContextSettings = Field(default_factory=ContextSettings)
    skills: SkillSettings = Field(default_factory=SkillSettings)

    @classmethod
    def load(cls, config_path: Optional[Path] = None) -> "Settings":
        """Load settings from TOML config file, falling back to defaults."""
        if config_path is None:
            config_path = Path.home() / ".config/simon/config.toml"

        if config_path.exists():
            import toml

            data = toml.load(config_path)
            return cls(
                general=GeneralSettings(**data.get("general", {})),
                anthropic=AnthropicSettings(**data.get("anthropic", {})),
                context=ContextSettings(**data.get("context", {})),
                skills=SkillSettings(**data.get("skills", {})),
            )

        return cls()


# Module-level singleton
_settings: Optional[Settings] = None


def get_settings() -> Settings:
    """Get or create the global settings instance."""
    global _settings
    if _settings is None:
        _settings = Settings.load()
    return _settings
