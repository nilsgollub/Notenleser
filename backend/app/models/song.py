from datetime import datetime
from typing import Optional
from sqlmodel import SQLModel, Field


class Song(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    title: str = Field(index=True)
    composer: Optional[str] = None
    key_signature: Optional[str] = None   # z. B. "C-Dur", "G-Dur"
    time_signature: Optional[str] = None  # z. B. "4/4"
    tempo_bpm: Optional[int] = None

    # Dateipfade (relativ zu data_dir)
    scan_image_path: Optional[str] = None
    musicxml_path: Optional[str] = None
    midi_path: Optional[str] = None
    audio_path: Optional[str] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class ScanJob(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    song_id: Optional[int] = Field(default=None, foreign_key="song.id")
    status: str = Field(default="pending")  # pending | processing | done | error
    error_message: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
