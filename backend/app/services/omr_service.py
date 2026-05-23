"""
OMR-Service: Wandelt ein Notenbild in MusicXML um.

Unterstützte Engines:
  - "oemer"  : Deep-Learning OMR (https://github.com/BreezeWhite/oemer)
  - "mock"   : Gibt eine Test-MusicXML zurück (ohne GPU/Modelle)
"""
import shutil
import subprocess
import tempfile
from pathlib import Path

from app.core.config import settings


async def image_to_musicxml(image_path: Path, output_path: Path) -> Path:
    if settings.omr_engine == "mock":
        return _mock_musicxml(output_path)
    return await _oemer_musicxml(image_path, output_path)


async def _oemer_musicxml(image_path: Path, output_path: Path) -> Path:
    """Ruft oemer als Subprocess auf – läuft blockierend in einem Thread-Pool."""
    import asyncio

    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _run_oemer, image_path, output_path)


def _run_oemer(image_path: Path, output_path: Path) -> Path:
    with tempfile.TemporaryDirectory() as tmp:
        result = subprocess.run(
            ["oemer", str(image_path), "-o", tmp],
            capture_output=True,
            text=True,
            timeout=300,
        )
        if result.returncode != 0:
            raise RuntimeError(f"oemer fehlgeschlagen: {result.stderr}")

        # oemer legt die MusicXML mit gleichem Basis-Namen ab
        candidates = list(Path(tmp).glob("*.musicxml")) + list(Path(tmp).glob("*.xml"))
        if not candidates:
            raise RuntimeError("oemer hat keine MusicXML-Datei erzeugt.")

        output_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(candidates[0], output_path)
    return output_path


def _mock_musicxml(output_path: Path) -> Path:
    """Erzeugt eine minimale MusicXML mit Frère Jacques (erste 4 Takte) als Test."""
    xml = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC
  "-//Recordare//DTD MusicXML 4.0 Partwise//EN"
  "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <work><work-title>Testlied (Mock)</work-title></work>
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>D</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
    </measure>
    <measure number="2">
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>D</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
    </measure>
    <measure number="3">
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>F</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>G</step><octave>5</octave></pitch><duration>2</duration><type>half</type></note>
    </measure>
    <measure number="4">
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>F</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>G</step><octave>5</octave></pitch><duration>2</duration><type>half</type></note>
    </measure>
  </part>
</score-partwise>
"""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(xml, encoding="utf-8")
    return output_path
