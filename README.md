# Notenleser

Scanne oder fotografiere ein Notenblatt – die App erkennt die Melodie und spielt sie ab. Gleichzeitig wird eine Bibliothek aller erfassten Lieder aufgebaut.

## Zielplattformen

| Plattform | Deployment |
|---|---|
| Android-Smartphone | PWA (installierbar) oder Capacitor-App |
| Home Assistant | Addon mit Ingress-Panel |

---

## Architektur

```
┌─────────────────────────────────────────────────────────────────┐
│                        FRONTEND (PWA / Vue 3)                   │
│  Kamera / Datei-Upload  →  Bibliothek  →  Wiedergabe-Player     │
└────────────────────────────┬────────────────────────────────────┘
                             │ REST + WebSocket
┌────────────────────────────▼────────────────────────────────────┐
│                      BACKEND (Python / FastAPI)                  │
│                                                                  │
│  ┌─────────────┐   ┌──────────────┐   ┌────────────────────┐    │
│  │ OMR-Service │   │ Music-Service│   │  Library-Service   │    │
│  │  (oemer /   │   │ (music21 +   │   │ (SQLite + Dateien) │    │
│  │  OpenCV)    │→  │  FluidSynth) │→  │                    │    │
│  └─────────────┘   └──────────────┘   └────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                             │ Docker
┌──────────────┐    ┌────────┴──────────┐
│  Android     │    │  Home Assistant   │
│  (PWA/APK)   │    │  Addon            │
└──────────────┘    └───────────────────┘
```

### Technologie-Stack

| Schicht | Technologie | Begründung |
|---|---|---|
| OMR (Notenerkennung) | **oemer** (Python) | Pure-Python, Deep-Learning, liefert MusicXML |
| Musikverarbeitung | **music21** | MusicXML → MIDI, Tonart/Tempo-Analyse |
| Audio-Synthese | **FluidSynth** + Soundfont | Hochwertige MIDI→Audio-Konvertierung |
| Backend API | **FastAPI** | Async, automatische OpenAPI-Doku |
| Datenbank | **SQLite** + SQLModel | Kein externer DB-Server nötig |
| Datei-Storage | Lokales Verzeichnis | Bilder, MusicXML, MIDI, Audio |
| Frontend | **Vue 3** + Vite (PWA) | Funktioniert als HA-Panel + Android |
| Containerisierung | **Docker** / docker-compose | Gleiche Basis für HA-Addon und Standalone |

---

## Umsetzungsplan

### Phase 1 – Fundament (Backend-Skeleton)
- [x] Projektstruktur anlegen
- [ ] FastAPI-App mit Health-Endpoint
- [ ] SQLite-Datenbankmodelle (Song, ScanJob)
- [ ] Datei-Upload-Endpoint (Bild entgegennehmen)
- [ ] Docker-Setup (Backend)

### Phase 2 – OMR-Integration (Notenerkennung)
- [ ] Bild-Vorverarbeitung mit OpenCV (Entzerrung, Kontrast, Graustufen)
- [ ] oemer einbinden → MusicXML-Output
- [ ] Fallback: einfache Linienerkennung für Grundtöne (OpenCV)
- [ ] MusicXML validieren und in DB speichern

### Phase 3 – Musikwiedergabe
- [ ] music21: MusicXML → MIDI
- [ ] FluidSynth: MIDI → WAV/MP3
- [ ] Streaming-Endpoint für Audio
- [ ] WebSocket für Echtzeit-Fortschrittsanzeige beim Scan

### Phase 4 – Lied-Bibliothek
- [ ] CRUD-API für Songs
- [ ] Thumbnail-Generierung aus Scan-Bild
- [ ] Suche nach Titel/Datum/Tonart
- [ ] Export als MIDI / MusicXML

### Phase 5 – Frontend (Vue 3 PWA)
- [ ] Kamera-Capture + Datei-Upload-UI
- [ ] Scan-Fortschrittsanzeige (WebSocket)
- [ ] Noten-Viewer (OpenSheetMusicDisplay)
- [ ] Audio-Player mit Play/Pause/Tempo
- [ ] Bibliotheks-Ansicht mit Suche
- [ ] PWA-Manifest (installierbar auf Android)

### Phase 6 – Plattform-Deployment
- [ ] Home Assistant Addon (config.yaml, Ingress)
- [ ] Android: PWA-Installation oder Capacitor-Wrapping
- [ ] CI/CD (GitHub Actions)

---

## Schnellstart (Entwicklung)

```bash
# Backend
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload

# Frontend
cd frontend
npm install
npm run dev
```

```bash
# Alles via Docker
docker-compose up
```

---

## Verzeichnisstruktur

```
Notenleser/
├── backend/
│   ├── app/
│   │   ├── main.py          # FastAPI Entry-Point
│   │   ├── api/             # Router (upload, songs, playback)
│   │   ├── core/            # Config, Datenbank-Setup
│   │   ├── models/          # SQLModel-Tabellen
│   │   └── services/        # OMR, Music, Library
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/
│   ├── src/
│   │   ├── components/      # Wiederverwendbare UI-Teile
│   │   ├── views/           # Seiten (Scan, Library, Player)
│   │   └── stores/          # Pinia State Management
│   ├── package.json
│   └── Dockerfile
├── homeassistant-addon/
│   ├── config.yaml          # HA Addon-Manifest
│   ├── Dockerfile
│   └── run.sh
├── data/                    # Laufzeit-Daten (gitignored)
│   ├── db/
│   ├── uploads/
│   └── audio/
├── docs/
│   └── architecture.md
└── docker-compose.yml
```
