# Technische Architektur

## Systemüberblick

```
┌───────────────────────────────────────────────────────────────────┐
│                       NUTZER-GERÄT                                │
│                                                                   │
│   Android (Chrome PWA)          Home Assistant Panel              │
│   ┌─────────────────────┐       ┌─────────────────────┐          │
│   │   Vue 3 SPA (PWA)   │       │ Vue 3 SPA (Ingress) │          │
│   └──────────┬──────────┘       └──────────┬──────────┘          │
└──────────────│───────────────────────────  │ ──────────────────────┘
               │ HTTP / WebSocket            │ HTTP / WebSocket
┌──────────────▼─────────────────────────────▼──────────────────────┐
│                    BACKEND  (FastAPI / Python 3.12)               │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐    │
│  │  /scan/*     │  │  /songs/*    │  │  /playback/*         │    │
│  │  Upload +    │  │  CRUD +      │  │  Audio / MIDI /      │    │
│  │  WebSocket   │  │  Suche       │  │  MusicXML / Timing   │    │
│  └──────┬───────┘  └──────┬───────┘  └──────────────────────┘    │
│         │                 │                                       │
│  ┌──────▼───────────────────────────────────────────────────┐    │
│  │                  Services-Schicht                         │    │
│  │                                                           │    │
│  │  omr_service.py          music_service.py                 │    │
│  │  ┌──────────────┐        ┌──────────────────────────────┐ │    │
│  │  │  Bild-       │        │ MusicXML → MIDI  (music21)   │ │    │
│  │  │  Preprocessing│       │ MIDI → WAV       (FluidSynth)│ │    │
│  │  │  oemer / mock │       │ Timing-Extraktion (Karaoke)  │ │    │
│  │  └──────────────┘        └──────────────────────────────┘ │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              Persistenz                                   │    │
│  │   SQLite (SQLModel)      /data  (Dateisystem)             │    │
│  │   songs / scan_jobs      uploads/ musicxml/ audio/        │    │
│  └──────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────┘
```

---

## Verarbeitungs-Pipeline

Ein Scan durchläuft folgende Schritte (asynchron im Hintergrund):

```
Bild-Upload (JPEG/PNG/PDF)
        │
        ▼
[1] Bild speichern  →  /data/uploads/<uuid>.jpg
        │
        ▼
[2] OMR: oemer      →  /data/musicxml/<id>.musicxml
        │                 Standard: MusicXML 4.0
        │
        ▼
[3] Metadaten: music21
        │  Tonart, Takt, Tempo, Komponist, Titel
        ▼
[4] Timing-Extraktion  →  /data/audio/<id>_timing.json
        │  Für jeden Ton: Zeit (s), Dauer (s), Takt, Tonhöhen
        │
        ▼
[5] MIDI: music21    →  /data/audio/<id>.mid
        │
        ▼
[6] Audio: FluidSynth →  /data/audio/<id>.wav
        │  (optional – Fallback: Browser-Synth)
        ▼
     Fertig – Song in SQLite gespeichert
```

Jeder Schritt sendet eine WebSocket-Benachrichtigung an das Frontend.

---

## Datenbank-Schema

```sql
-- Song: Ein erkanntes Lied
CREATE TABLE song (
    id              INTEGER PRIMARY KEY,
    title           TEXT NOT NULL,
    composer        TEXT,
    key_signature   TEXT,   -- z. B. "C major", "g minor"
    time_signature  TEXT,   -- z. B. "4/4", "3/4"
    tempo_bpm       INTEGER,
    scan_image_path TEXT,   -- Absoluter Pfad auf dem Server
    musicxml_path   TEXT,
    midi_path       TEXT,
    audio_path      TEXT,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ScanJob: Verarbeitungs-Status eines Uploads
CREATE TABLE scanjob (
    id            INTEGER PRIMARY KEY,
    song_id       INTEGER REFERENCES song(id),
    status        TEXT DEFAULT 'pending',
    error_message TEXT,
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## Karaoke-Mechanismus

Die Karaoke-Synchronisation besteht aus drei zusammenspielenden Teilen:

### 1. Backend: Timing-Extraktion (music21)

```python
# Für jede Note im Score:
offset_seconds = note.offset * (60.0 / bpm)
duration_seconds = note.duration.quarterLength * (60.0 / bpm)

event = {
    "time": offset_seconds,    # Wann beginnt die Note?
    "duration": duration_seconds,
    "measure": note.measureNumber,
    "pitches": ["C5", "E5"],   # Akkord-Töne
}
```

Das Ergebnis ist ein sortiertes Array von Note-Events mit absoluten Zeitstempeln.

### 2. Frontend: OSMD-Cursor

[OpenSheetMusicDisplay](https://opensheetmusicdisplay.org/) rendert die MusicXML
als SVG und stellt einen Cursor zur Verfügung:

```javascript
osmd.cursor.show()   // Goldenen Cursor anzeigen
osmd.cursor.next()   // Eine Note vorspringen
osmd.cursor.reset()  // Zum Anfang zurück
```

Der Cursor hebt automatisch die aktuelle Note hervor und scrollt das Notenblatt mit.

### 3. Frontend: Sync-Loop

```javascript
function karaokeLoop() {
    const t = audio.currentTime  // Aktuelle Abspielzeit

    // Cursor vorspulen bis Zeitstempel passt
    while (cursorStep < events.length && t >= events[cursorStep].time) {
        if (cursorStep > 0) osmd.cursor.next()
        cursorStep++
    }
    requestAnimationFrame(karaokeLoop)
}
```

**Seek-Toleranz:** Wird im Audio gesprungen (> 2 Noten Abweichung), wird der
Cursor automatisch auf die richtige Position zurückgesetzt.

### MIDI-Fallback (Tone.js)

Wenn kein WAV verfügbar ist, übernimmt Tone.js die Wiedergabe.
Die Note-Events aus dem Timing-JSON werden direkt als Tone.js-Schedule eingeplant:

```javascript
timingData.events.forEach(ev => {
    Tone.Transport.schedule(time => {
        synth.triggerAttackRelease(ev.pitches, ev.duration, time)
    }, ev.time)
})
Tone.Transport.start()
```

Der Karaoke-Cursor läuft parallel per `requestAnimationFrame` weiter.

---

## OMR-Engine: oemer

[oemer](https://github.com/BreezeWhite/oemer) ist ein Deep-Learning-basiertes
Optical Music Recognition System.

### Verarbeitungspipeline von oemer:

1. **Staff-Line-Detektion** – Erkennung der Notenlinien
2. **Symbol-Segmentierung** – Noten, Vorzeichen, Taktstriche
3. **Symbol-Klassifikation** – CNN-Modell identifiziert Notenart
4. **Rekonstruktion** – Aufbau des Musik-Graphen
5. **MusicXML-Export** – Standardisierter Output

### Warum oemer?

| Kriterium | oemer | Audiveris | SheetVision |
|---|---|---|---|
| Sprache | Python | Java | Python |
| Qualität | gut | sehr gut | einfach |
| Abhängigkeiten | PyTorch | JRE | OpenCV |
| Docker-Größe | ~3 GB | ~1,5 GB | ~500 MB |
| Lizenz | MIT | AGPL | MIT |
| **Wahl** | ✅ | Reserve | Fallback |

**Audiveris** bleibt als Reserve-Option (bessere Qualität bei komplexen Partituren).
Bei Bedarf kann die Engine durch Anpassung von `omr_service.py` gewechselt werden.

---

## Frontend-Architektur

```
src/
├── main.js               # App-Initialisierung (Vue + Pinia + Router)
├── App.vue               # Shell (Header + BottomNav + Router-Outlet)
├── router/index.js       # Route-Definitionen
├── assets/global.css     # Design-System (CSS Custom Properties)
│
├── stores/
│   ├── songs.js          # API-Calls (Axios), Song-Liste
│   └── player.js         # Wiedergabe-Zustand (isPlaying, Karaoke, Tempo)
│
├── views/
│   ├── LibraryView.vue   # Bibliothek mit Suche
│   ├── ScanView.vue      # Upload + WebSocket-Fortschritt
│   └── PlayerView.vue    # Notenblatt + Player + Karaoke-Sync
│
└── components/
    ├── AppHeader.vue      # Logo + Navigation
    ├── BottomNav.vue      # Mobile-Navigation (Bibliothek / Scan)
    ├── SongCard.vue       # Karte in der Bibliotheks-Ansicht
    ├── ScanProgress.vue   # Fortschrittsbalken (WebSocket-Status)
    ├── SheetViewer.vue    # OSMD-Wrapper (MusicXML → SVG)
    └── AudioPlayer.vue    # Steuerleiste (Play, Tempo, Seek, Karaoke)
```

### State-Management

| Store | Zustand | Verwendung |
|---|---|---|
| `songs` | Song-Liste, Lade-Status | LibraryView, ScanView |
| `player` | isPlaying, currentTime, Karaoke-Flag, Tempo | PlayerView, AudioPlayer |

---

## PWA-Architektur

```
Browser
  │
  ├── Service Worker (vite-plugin-pwa / Workbox)
  │     ├── Cache-First für JS/CSS/Fonts
  │     └── Network-First für /playback/* (Audio-Streaming)
  │
  └── Web App Manifest
        ├── display: standalone  → kein Browser-Chrome
        ├── start_url: /
        └── icons: 192px + 512px (maskable)
```

---

## Deployment-Varianten

### Home Assistant Addon

```
HA-Supervisor
  └── Docker: notenleser-addon
        ├── FastAPI (Port 8000, intern)
        ├── Vue 3 dist/ (statisch von FastAPI)
        └── /data → HA Addon-Config Volume
```

HA routet Anfragen via **Ingress** durch, sodass kein Port nach außen geöffnet werden muss.

### Standalone Docker

```
Host-Port 8000
  └── nginx
        ├── → Backend API (proxy_pass :8000)
        └── → Frontend dist/ (try_files)
```

### Entwicklung (Hot-Reload)

```
Vite Dev Server (:5173) ──proxy──► FastAPI (:8000)
uvicorn --reload
```
