from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from app.core.database import get_session
from app.models.song import Song
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/playback", tags=["playback"])


@router.get("/{song_id}/audio")
async def stream_audio(song_id: int, session: AsyncSession = Depends(get_session)):
    song = await session.get(Song, song_id)
    if not song:
        raise HTTPException(404, "Lied nicht gefunden")
    if not song.audio_path or not Path(song.audio_path).exists():
        raise HTTPException(404, "Audio-Datei nicht verfügbar (noch kein Render oder FluidSynth fehlt)")
    return FileResponse(song.audio_path, media_type="audio/wav", filename=f"{song.title}.wav")


@router.get("/{song_id}/midi")
async def download_midi(song_id: int, session: AsyncSession = Depends(get_session)):
    song = await session.get(Song, song_id)
    if not song:
        raise HTTPException(404, "Lied nicht gefunden")
    if not song.midi_path or not Path(song.midi_path).exists():
        raise HTTPException(404, "MIDI-Datei nicht verfügbar")
    return FileResponse(song.midi_path, media_type="audio/midi", filename=f"{song.title}.mid")


@router.get("/{song_id}/musicxml")
async def download_musicxml(song_id: int, session: AsyncSession = Depends(get_session)):
    song = await session.get(Song, song_id)
    if not song:
        raise HTTPException(404, "Lied nicht gefunden")
    if not song.musicxml_path or not Path(song.musicxml_path).exists():
        raise HTTPException(404, "MusicXML nicht verfügbar")
    return FileResponse(song.musicxml_path, media_type="application/xml", filename=f"{song.title}.musicxml")
