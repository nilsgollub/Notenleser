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

    # FluidSynth Soundfont (Standard-Pfad in Debian/Ubuntu)
    soundfont_path: Path = Path("/usr/share/sounds/sf2/FluidR3_GM.sf2")

    # OMR: "oemer" oder "mock" (für Tests ohne GPU)
    omr_engine: str = "oemer"

    class Config:
        env_file = ".env"


settings = Settings()

# Verzeichnisse beim Import anlegen
for _dir in (settings.upload_dir, settings.audio_dir, settings.musicxml_dir, settings.data_dir / "db"):
    _dir.mkdir(parents=True, exist_ok=True)
