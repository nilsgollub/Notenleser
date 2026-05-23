"""
Music-Service: MusicXML → MIDI → Audio (WAV) + Timing-Extraktion für Karaoke
"""
import json
from pathlib import Path
from typing import Optional

from app.core.config import settings


def musicxml_to_midi(musicxml_path: Path, midi_path: Path) -> Path:
    from music21 import converter
    score = converter.parse(str(musicxml_path))
    midi_path.parent.mkdir(parents=True, exist_ok=True)
    score.write("midi", fp=str(midi_path))
    return midi_path


def extract_metadata(musicxml_path: Path) -> dict:
    from music21 import converter, tempo as m21tempo
    score = converter.parse(str(musicxml_path))
    meta = {}
    if score.metadata:
        meta["title"] = score.metadata.title or "Unbekanntes Lied"
        meta["composer"] = score.metadata.composer
    else:
        meta["title"] = "Unbekanntes Lied"
        meta["composer"] = None

    try:
        key = score.analyze("key")
        meta["key_signature"] = str(key)
    except Exception:
        meta["key_signature"] = None

    try:
        ts = score.recurse().getElementsByClass("TimeSignature").first()
        meta["time_signature"] = f"{ts.numerator}/{ts.denominator}" if ts else None
    except Exception:
        meta["time_signature"] = None

    try:
        mm = score.flatten().getElementsByClass(m21tempo.MetronomeMark).first()
        meta["tempo_bpm"] = int(mm.number) if mm else None
    except Exception:
        meta["tempo_bpm"] = None

    return meta


def extract_note_timings(musicxml_path: Path) -> dict:
    """
    Gibt für jeden Ton: Zeit in Sekunden, Dauer, Taktnummer, Tonhöhen.
    Wird für den Karaoke-Cursor im Frontend verwendet.
    """
    from music21 import converter, tempo as m21tempo

    score = converter.parse(str(musicxml_path))
    flat = score.flatten()

    mm = flat.getElementsByClass(m21tempo.MetronomeMark).first()
    bpm = float(mm.number) if mm else 120.0
    spq = 60.0 / bpm  # seconds per quarter note

    events = []
    for el in flat.notesAndRests:
        if el.isRest:
            continue
        t = round(float(el.offset) * spq, 3)
        dur = round(float(el.duration.quarterLength) * spq, 3)
        measure = el.measureNumber or 0

        if el.isChord:
            pitches = [p.nameWithOctave for p in el.pitches]
        else:
            pitches = [el.pitch.nameWithOctave]

        events.append({"time": t, "duration": dur, "measure": measure, "pitches": pitches})

    events.sort(key=lambda e: e["time"])
    total = round(events[-1]["time"] + events[-1]["duration"], 3) if events else 0.0

    return {"bpm": round(bpm, 1), "total_duration": total, "events": events}


def save_timing(song_id: int, timing: dict) -> Path:
    path = settings.audio_dir / f"{song_id}_timing.json"
    path.write_text(json.dumps(timing), encoding="utf-8")
    return path


def midi_to_audio(midi_path: Path, audio_path: Path, soundfont: Optional[Path] = None) -> Path:
    """Konvertiert MIDI → WAV via FluidSynth CLI."""
    import subprocess
    sf = str(soundfont or settings.soundfont_path)
    audio_path.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["fluidsynth", "-ni", sf, str(midi_path), "-F", str(audio_path), "-r", "44100"],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode != 0:
        raise RuntimeError(f"FluidSynth: {result.stderr}")
    return audio_path
