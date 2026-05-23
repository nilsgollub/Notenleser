import json
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_session
from app.models.song import Song

router = APIRouter(prefix="/playback", tags=["playback"])


async def _get_song_or_404(song_id: int, session: AsyncSession) -> Song:
    song = await session.get(Song, song_id)
    if not song:
        raise HTTPException(404, "Lied nicht gefunden")
    return song


@router.get("/{song_id}/audio")
async def stream_audio(song_id: int, session: AsyncSession = Depends(get_session)):
    song = await _get_song_or_404(song_id, session)
    if not song.audio_path or not Path(song.audio_path).exists():
        raise HTTPException(404, "Audio-Datei nicht verfügbar – nur MIDI vorhanden")
    return FileResponse(song.audio_path, media_type="audio/wav", filename=f"{song.title}.wav")


@router.get("/{song_id}/midi")
async def download_midi(song_id: int, session: AsyncSession = Depends(get_session)):
    song = await _get_song_or_404(song_id, session)
    if not song.midi_path or not Path(song.midi_path).exists():
        raise HTTPException(404, "MIDI nicht verfügbar")
    return FileResponse(song.midi_path, media_type="audio/midi", filename=f"{song.title}.mid")


@router.get("/{song_id}/musicxml")
async def download_musicxml(song_id: int, session: AsyncSession = Depends(get_session)):
    song = await _get_song_or_404(song_id, session)
    if not song.musicxml_path or not Path(song.musicxml_path).exists():
        raise HTTPException(404, "MusicXML nicht verfügbar")
    return FileResponse(song.musicxml_path, media_type="application/xml", filename=f"{song.title}.musicxml")


@router.get("/{song_id}/image")
async def get_image(song_id: int, session: AsyncSession = Depends(get_session)):
    song = await _get_song_or_404(song_id, session)
    if not song.scan_image_path or not Path(song.scan_image_path).exists():
        raise HTTPException(404, "Bild nicht verfügbar")
    suffix = Path(song.scan_image_path).suffix.lower()
    media = {"jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png"}.get(suffix, "image/jpeg")
    return FileResponse(song.scan_image_path, media_type=media)


@router.get("/{song_id}/timing")
async def get_timing(song_id: int, session: AsyncSession = Depends(get_session)):
    """Gibt Note-Timing-Daten für den Karaoke-Cursor zurück."""
    await _get_song_or_404(song_id, session)
    timing_path = settings.audio_dir / f"{song_id}_timing.json"
    if not timing_path.exists():
        raise HTTPException(404, "Timing-Daten nicht verfügbar")
    return json.loads(timing_path.read_text(encoding="utf-8"))
