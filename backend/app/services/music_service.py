"""
Music-Service: MusicXML → MIDI → Audio (WAV/MP3)
"""
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
    from music21 import converter

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
        from music21 import tempo as m21tempo
        mm = score.recurse().getElementsByClass(m21tempo.MetronomeMark).first()
        meta["tempo_bpm"] = int(mm.number) if mm else None
    except Exception:
        meta["tempo_bpm"] = None

    return meta


def midi_to_audio(midi_path: Path, audio_path: Path, soundfont: Optional[Path] = None) -> Path:
    """Konvertiert MIDI → WAV via FluidSynth."""
    import subprocess

    sf = str(soundfont or settings.soundfont_path)
    audio_path.parent.mkdir(parents=True, exist_ok=True)

    result = subprocess.run(
        [
            "fluidsynth",
            "-ni",
            sf,
            str(midi_path),
            "-F", str(audio_path),
            "-r", "44100",
        ],
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode != 0:
        raise RuntimeError(f"FluidSynth fehlgeschlagen: {result.stderr}")
    return audio_path
