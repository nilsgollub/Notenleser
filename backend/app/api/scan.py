"""
Scan-Endpoint: Bild hochladen → OMR → MIDI/Audio/Timing → Song in DB.
WebSocket liefert Echtzeit-Fortschritt.
"""
import asyncio
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, UploadFile, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_session, AsyncSessionLocal
from app.models.song import Song, ScanJob
from app.services import omr_service, music_service

router = APIRouter(prefix="/scan", tags=["scan"])

_ws_connections: dict[str, WebSocket] = {}


@router.post("/upload", status_code=202)
async def upload_scan(
    file: UploadFile = File(...),
    title: str = Form(default=""),
    session: AsyncSession = Depends(get_session),
):
    job_id_str = str(uuid.uuid4())
    suffix = Path(file.filename or "scan.jpg").suffix or ".jpg"
    image_path = settings.upload_dir / f"{job_id_str}{suffix}"
    image_path.write_bytes(await file.read())

    song = Song(title=title or Path(file.filename or "Unbekannt").stem, scan_image_path=str(image_path))
    session.add(song)
    job = ScanJob(status="pending")
    session.add(job)
    await session.commit()
    await session.refresh(song)
    await session.refresh(job)

    # Hintergrundtask bekommt eigene Session
    asyncio.create_task(_process_scan(job.id, song.id, image_path))
    return {"job_id": job.id, "song_id": song.id}


async def _notify(job_id: int, msg: str):
    ws = _ws_connections.get(str(job_id))
    if ws:
        try:
            await ws.send_json({"job_id": job_id, "status": msg})
        except Exception:
            pass


async def _process_scan(job_id: int, song_id: int, image_path: Path):
    async with AsyncSessionLocal() as session:
        try:
            job = await session.get(ScanJob, job_id)
            song = await session.get(Song, song_id)
            job.status = "processing"
            await session.commit()

            await _notify(job_id, "omr")
            musicxml_path = settings.musicxml_dir / f"{song_id}.musicxml"
            await omr_service.image_to_musicxml(image_path, musicxml_path)
            song.musicxml_path = str(musicxml_path)

            await _notify(job_id, "metadata")
            meta = music_service.extract_metadata(musicxml_path)
            song.title = meta.get("title") or song.title
            song.composer = meta.get("composer")
            song.key_signature = meta.get("key_signature")
            song.time_signature = meta.get("time_signature")
            song.tempo_bpm = meta.get("tempo_bpm")

            await _notify(job_id, "timing")
            try:
                timing = music_service.extract_note_timings(musicxml_path)
                music_service.save_timing(song_id, timing)
            except Exception:
                pass

            await _notify(job_id, "midi")
            midi_path = settings.audio_dir / f"{song_id}.mid"
            music_service.musicxml_to_midi(musicxml_path, midi_path)
            song.midi_path = str(midi_path)

            await _notify(job_id, "audio")
            audio_path = settings.audio_dir / f"{song_id}.wav"
            try:
                music_service.midi_to_audio(midi_path, audio_path)
                song.audio_path = str(audio_path)
            except Exception:
                pass  # MIDI als Fallback reicht

            job.status = "done"
            await session.commit()
            await _notify(job_id, "done")

        except Exception as exc:
            job = await session.get(ScanJob, job_id)
            if job:
                job.status = "error"
                job.error_message = str(exc)
                await session.commit()
            await _notify(job_id, f"error:{exc}")


@router.get("/job/{job_id}")
async def get_job(job_id: int, session: AsyncSession = Depends(get_session)):
    job = await session.get(ScanJob, job_id)
    if not job:
        from fastapi import HTTPException
        raise HTTPException(404, "Job nicht gefunden")
    return job


@router.websocket("/ws/{job_id}")
async def scan_ws(websocket: WebSocket, job_id: str):
    await websocket.accept()
    _ws_connections[job_id] = websocket
    try:
        while True:
            await asyncio.sleep(30)
    except WebSocketDisconnect:
        _ws_connections.pop(job_id, None)
