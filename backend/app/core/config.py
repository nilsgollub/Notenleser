from pydantic_settings import BaseSettings
from pathlib import Path


class Settings(BaseSettings):
    app_name: str = "Notenleser"
    app_version: str = "0.1.0"

    data_dir: Path = Path("/data")
    upload_dir: Path = data_dir / "uploads"
    audio_dir: Path = data_dir / "audio"
    musicxml_dir: Path = data_dir / "musicxml"
    db_url: str = "sqlite+aiosqlite:////data/db/notenleser.db"

    soundfont_path: Path = Path("/usr/share/sounds/sf2/FluidR3_GM.sf2")
    omr_engine: str = "mock"

    # CORS: "*" für lokales Heimnetz, ansonsten konkrete Origins eintragen
    # z. B.: cors_origins=["http://192.168.1.42:5173","http://homeassistant.local"]
    cors_origins: list[str] = ["*"]

    # Upload-Beschränkungen
    max_upload_mb: int = 20

    class Config:
        env_file = ".env"


settings = Settings()

for _dir in (settings.upload_dir, settings.audio_dir, settings.musicxml_dir, settings.data_dir / "db"):
    _dir.mkdir(parents=True, exist_ok=True)
