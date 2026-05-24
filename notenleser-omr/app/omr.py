"""OMR pipeline: image → MusicXML (via oemer) → JSON (via music21)."""

import glob
import logging
import os
import subprocess
import tempfile
from typing import Any

import music21 as m21
import music21.chord
import music21.key
import music21.metadata
import music21.meter
import music21.note
import music21.pitch
import music21.tempo

logger = logging.getLogger(__name__)

# German note names for key signature conversion
_GERMAN_NAMES: dict[str, str] = {
    "C": "C", "D": "D", "E": "E", "F": "F", "G": "G", "A": "A", "B": "H",
    "C#": "Cis", "D#": "Dis", "F#": "Fis", "G#": "Gis", "A#": "Ais",
    "Cb": "Ces", "Db": "Des", "Eb": "Es", "Fb": "Fes",
    "Gb": "Ges", "Ab": "As", "Bb": "B",
}


def recognize_sheet_music(image_path: str) -> dict[str, Any]:
    """Run oemer on *image_path* and return a Song-compatible dict."""
    with tempfile.TemporaryDirectory() as out_dir:
        _run_oemer(image_path, out_dir)
        xml_path = _find_musicxml(out_dir)
        if xml_path is None:
            logger.warning("Keine MusicXML-Datei erzeugt.")
            return _empty_result()
        return _parse_musicxml(xml_path)


def _run_oemer(image_path: str, out_dir: str) -> None:
    cmd = ["oemer", image_path, "-o", out_dir, "--use-tf", "false"]
    logger.info("oemer: %s", " ".join(cmd))
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600,  # 10 Min. für RPi4
        )
        if result.returncode != 0:
            logger.error("oemer stderr: %s", result.stderr[-2000:])
    except subprocess.TimeoutExpired:
        logger.error("oemer Timeout nach 10 Minuten.")


def _find_musicxml(directory: str) -> str | None:
    for pattern in ("**/*.musicxml", "**/*.xml"):
        matches = glob.glob(os.path.join(directory, pattern), recursive=True)
        if matches:
            return matches[0]
    return None


def _parse_musicxml(xml_path: str) -> dict[str, Any]:
    score = m21.converter.parse(xml_path)

    title, composer = _extract_metadata(score)
    key_str = _extract_key(score)
    time_sig = _extract_time_signature(score)
    bpm = _extract_tempo(score)
    notes = _extract_notes(score)

    return {
        "title": title or "Unbekanntes Lied",
        "composer": composer,
        "key": key_str,
        "time_signature": time_sig,
        "tempo_bpm": bpm,
        "notes": notes,
    }


def _extract_metadata(score: m21.stream.Score) -> tuple[str, str]:
    for meta in score.recurse().getElementsByClass(m21.metadata.Metadata):
        title = str(meta.title or "").strip()
        composer = str(meta.composer or "").strip()
        return title, composer
    return "", ""


def _extract_key(score: m21.stream.Score) -> str:
    try:
        key = score.analyze("key")
        tonic = key.tonic.name.replace("-", "b")
        name = _GERMAN_NAMES.get(tonic, tonic)
        if key.mode == "minor":
            return f"{name.lower()}-Moll"
        return f"{name}-Dur"
    except Exception:
        return ""


def _extract_time_signature(score: m21.stream.Score) -> str:
    sigs = list(score.recurse().getElementsByClass(m21.meter.TimeSignature))
    if sigs:
        ts = sigs[0]
        return f"{ts.numerator}/{ts.denominator}"
    return "4/4"


def _extract_tempo(score: m21.stream.Score) -> int:
    marks = list(score.recurse().getElementsByClass(m21.tempo.MetronomeMark))
    for mark in marks:
        if mark.number:
            return int(mark.number)
    return 100


def _extract_notes(score: m21.stream.Score) -> list[dict[str, Any]]:
    # Use the top part (index 0) as the melody voice
    part = score.parts[0] if score.parts else score

    notes: list[dict[str, Any]] = []
    seen_offsets: set[float] = set()  # avoid duplicate notes at same position

    for elem in part.recurse().getElementsByClass(
        [m21.note.Note, m21.note.Rest, m21.chord.Chord]
    ):
        offset = float(elem.offset)
        if offset in seen_offsets:
            continue
        seen_offsets.add(offset)

        measure_num = getattr(elem, "measureNumber", None) or 1
        duration = float(elem.quarterLength)
        if duration <= 0:
            continue

        if isinstance(elem, m21.note.Note):
            entry: dict[str, Any] = {
                "pitch": _pitch_str(elem.pitch),
                "duration_beats": duration,
                "measure": measure_num,
            }
            if elem.lyrics:
                lyric = " ".join(
                    lyr.text for lyr in elem.lyrics if lyr.text
                ).strip()
                if lyric:
                    entry["lyric"] = lyric
            notes.append(entry)

        elif isinstance(elem, m21.note.Rest):
            notes.append(
                {"pitch": "REST", "duration_beats": duration, "measure": measure_num}
            )

        elif isinstance(elem, m21.chord.Chord) and elem.notes:
            # Melody = highest pitch
            top = max(elem.notes, key=lambda n: n.pitch.ps)
            notes.append(
                {
                    "pitch": _pitch_str(top.pitch),
                    "duration_beats": duration,
                    "measure": measure_num,
                }
            )

    return notes


def _pitch_str(pitch: m21.pitch.Pitch) -> str:
    """Convert music21 Pitch to our notation: C#4, Bb3, REST not applicable here."""
    step = pitch.step
    alter = pitch.alter
    octave = pitch.octave if pitch.octave is not None else 4
    if alter == 1:
        acc = "#"
    elif alter == -1:
        acc = "b"
    elif alter == 2:
        acc = "##"
    elif alter == -2:
        acc = "bb"
    else:
        acc = ""
    return f"{step}{acc}{octave}"


def _empty_result() -> dict[str, Any]:
    return {
        "title": "Unbekanntes Lied",
        "composer": "",
        "key": "",
        "time_signature": "4/4",
        "tempo_bpm": 100,
        "notes": [],
    }
