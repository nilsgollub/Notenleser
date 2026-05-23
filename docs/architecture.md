# Architektur-Entscheidungen

## OMR-Engine: oemer

**Gewählt:** [oemer](https://github.com/BreezeWhite/oemer) (Python, Deep Learning, MIT-Lizenz)

**Alternativen bewertet:**

| Engine | Sprache | Qualität | Komplexität | Entscheidung |
|---|---|---|---|---|
| **oemer** | Python | gut | mittel | ✅ gewählt |
| Audiveris | Java | sehr gut | hoch (JRE) | Reserveoption |
| SheetVision | Python/CV | einfach | niedrig | Fallback für einfache Noten |
| Cloud-API | - | variabel | niedrig | datenschutzproblematisch |

**Warum oemer:** Kein Java-Dependency, pure Python, läuft im Container, Output ist MusicXML (Industriestandard).

## Frontend: Vue 3 PWA

**Warum PWA statt nativer App:**
- Läuft auf Android (installierbar aus Chrome via „Zum Startbildschirm hinzufügen")
- Läuft als Home Assistant Ingress-Panel (iframe)
- Ein Codebase für beide Zielplattformen
- Kamera-API (`getUserMedia`) funktioniert in modernen Android-Browsern

**Upgrade-Pfad:** Falls native Funktionen nötig (z. B. Hintergrund-Zugriff), kann das Vue-Frontend mit [Capacitor](https://capacitorjs.com/) in eine APK verpackt werden – minimaler Umbau.

## Audio-Pipeline

```
Bild → OpenCV (Vorverarbeitung) → oemer (OMR) → MusicXML
     → music21 (Analyse + MIDI) → FluidSynth (WAV)
```

**Fallback ohne FluidSynth:** MIDI-Datei wird trotzdem bereitgestellt; der Browser kann MIDI-Playback via [MIDI.js](https://galacticmilkshake.com/MIDIjs/) oder [Tone.js](https://tonejs.github.io/) im Frontend übernehmen.

## Datenbank: SQLite

- Kein externer Datenbankserver erforderlich
- Passt perfekt zu Home Assistant Addon (persistente Datei in `/data`)
- Bei Bedarf Migration zu PostgreSQL möglich (SQLModel ist ORM-agnostisch)

## Home Assistant Integration

Das Addon nutzt **Ingress** – HA proxied die Weboberfläche direkt, kein offener Port nötig. Die API ist damit automatisch hinter HA-Authentifizierung geschützt.
