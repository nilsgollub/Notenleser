# Entwicklungsumgebung

## Voraussetzungen

| Tool | Version | Verwendung |
|---|---|---|
| Python | ≥ 3.11 | Backend |
| Node.js | ≥ 20 | Frontend |
| Docker + Compose | beliebig | Schnellstart |
| git | beliebig | Versionskontrolle |

Optional (für echte Notenerkennung):
- FluidSynth + fluid-soundfont-gm
- PyTorch + oemer

---

## Lokale Entwicklung (ohne Docker)

### Backend aufsetzen

```bash
cd backend

# Virtuelle Umgebung
python3 -m venv .venv
source .venv/bin/activate        # Linux/macOS
.venv\Scripts\activate           # Windows

# Abhängigkeiten
pip install -r requirements.txt

# Laufzeit-Verzeichnisse anlegen
mkdir -p /tmp/notenleser/{uploads,audio,musicxml,db}

# Umgebungsvariablen (Development)
cat > .env << 'EOF'
OMR_ENGINE=mock
DATA_DIR=/tmp/notenleser
EOF

# Server starten (Hot-Reload)
uvicorn app.main:app --reload --port 8000
```

Der API-Server ist dann unter http://localhost:8000 erreichbar.  
Interaktive Doku: http://localhost:8000/docs

### Frontend aufsetzen

```bash
cd frontend

# Abhängigkeiten
npm install

# Dev-Server starten (Vite mit Proxy zu :8000)
npm run dev
```

Frontend läuft unter http://localhost:5173 und proxied alle
API-Anfragen automatisch zum Backend.

---

## Projektstruktur

```
Notenleser/
│
├── backend/                     Backend (Python / FastAPI)
│   ├── app/
│   │   ├── main.py              FastAPI-App, Static-Files, CORS
│   │   ├── api/
│   │   │   ├── scan.py          Upload-Endpoint, WebSocket, Hintergrundverarbeitung
│   │   │   ├── songs.py         CRUD-Endpoints für die Bibliothek
│   │   │   └── playback.py      Audio/MIDI/MusicXML/Timing-Download
│   │   ├── core/
│   │   │   ├── config.py        Einstellungen (pydantic-settings)
│   │   │   └── database.py      SQLite-Setup, async Session
│   │   ├── models/
│   │   │   └── song.py          SQLModel-Tabellen (Song, ScanJob)
│   │   └── services/
│   │       ├── omr_service.py   Notenerkennung (oemer + Mock)
│   │       └── music_service.py MusicXML→MIDI→WAV, Timing-Extraktion
│   ├── requirements.txt
│   └── Dockerfile
│
├── frontend/                    Frontend (Vue 3 / Vite / PWA)
│   ├── src/
│   │   ├── main.js              App-Bootstrap
│   │   ├── App.vue              Shell (Header + BottomNav + Router-View)
│   │   ├── router/index.js      Routen: / , /scan , /songs/:id
│   │   ├── assets/global.css    Design-System (CSS Custom Properties)
│   │   ├── stores/
│   │   │   ├── songs.js         API-Calls, Song-State (Pinia)
│   │   │   └── player.js        Wiedergabe-State (Pinia)
│   │   ├── views/
│   │   │   ├── LibraryView.vue  Bibliothek mit Suche
│   │   │   ├── ScanView.vue     Upload + Kamera + Fortschritt
│   │   │   └── PlayerView.vue   Notenblatt + Player + Karaoke
│   │   └── components/
│   │       ├── AppHeader.vue    Logo + Titel
│   │       ├── BottomNav.vue    Mobile-Navigation
│   │       ├── SongCard.vue     Karte in der Bibliotheks-Liste
│   │       ├── ScanProgress.vue WebSocket-Fortschrittsbalken
│   │       ├── SheetViewer.vue  OpenSheetMusicDisplay-Wrapper
│   │       └── AudioPlayer.vue  Steuerleiste (Play/Pause/Seek/Tempo)
│   ├── public/manifest.json     PWA-Manifest
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js           Vite + PWA-Plugin + API-Proxy
│   ├── nginx.conf               Nginx für Produktions-Container
│   └── Dockerfile               Multi-Stage (Build + nginx)
│
├── homeassistant-addon/         HA Addon
│   ├── config.yaml              Addon-Manifest (Ingress, Arch)
│   ├── Dockerfile               Alpine-basiert
│   └── run.sh                   Startup-Skript (liest HA-Config)
│
├── docs/                        Diese Dokumentation
│   ├── setup.md
│   ├── architecture.md
│   ├── api.md
│   ├── karaoke.md
│   ├── homeassistant.md
│   ├── android.md
│   └── development.md
│
├── .github/workflows/ci.yml     GitHub Actions CI
├── docker-compose.yml           Dev-Umgebung
└── README.md
```

---

## Neue OMR-Engine einbinden

Die Engine-Abstraktion liegt in `backend/app/services/omr_service.py`.
Eine neue Engine hinzufügen:

```python
# omr_service.py

async def image_to_musicxml(image_path: Path, output_path: Path) -> Path:
    if settings.omr_engine == "mock":
        return _mock_musicxml(output_path)
    if settings.omr_engine == "audiveris":
        return await _audiveris_musicxml(image_path, output_path)  # neu
    return await _oemer_musicxml(image_path, output_path)

async def _audiveris_musicxml(image_path: Path, output_path: Path) -> Path:
    import asyncio
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _run_audiveris, image_path, output_path)

def _run_audiveris(image_path: Path, output_path: Path) -> Path:
    import subprocess
    result = subprocess.run(
        ["java", "-jar", "/opt/audiveris.jar", "-export", "-output", str(output_path.parent), str(image_path)],
        timeout=300,
    )
    # ... Ergebnis-Datei finden und zurückgeben
```

Danach in der `.env` setzen:
```dotenv
OMR_ENGINE=audiveris
```

---

## API testen

### curl-Beispiele

```bash
# Health-Check
curl http://localhost:8000/health

# Lied scannen (Mock)
curl -X POST http://localhost:8000/scan/upload \
  -F "file=@/pfad/zum/noten.jpg" \
  -F "title=Testlied"

# Alle Lieder
curl http://localhost:8000/songs/

# Timing-Daten
curl http://localhost:8000/playback/1/timing | python3 -m json.tool

# Audio herunterladen
curl http://localhost:8000/playback/1/audio -o lied.wav
```

### Swagger UI

http://localhost:8000/docs – alle Endpoints interaktiv ausprobieren.

---

## CI / GitHub Actions

Die Pipeline `.github/workflows/ci.yml` läuft bei jedem Push und prüft:

| Job | Was wird geprüft? |
|---|---|
| `backend` | Python-Syntax aller Backend-Module |
| `frontend` | `npm run build` muss erfolgreich sein |
| `docker` | Backend-Docker-Image muss gebaut werden können |

---

## Linting & Code-Style

### Backend (Python)

```bash
# Typen prüfen
cd backend
pip install mypy
mypy app/

# Formatierung
pip install black
black app/
```

### Frontend (JavaScript)

```bash
cd frontend
npm install --save-dev eslint @eslint/js eslint-plugin-vue
npx eslint src/
```

---

## Neue Ansicht / Route hinzufügen

1. Neue Datei `frontend/src/views/MeineAnsicht.vue` erstellen
2. In `frontend/src/router/index.js` eintragen:

```javascript
import MeineAnsicht from '../views/MeineAnsicht.vue'

{ path: '/meine-route', component: MeineAnsicht }
```

3. Falls nötig: Link in `BottomNav.vue` oder `AppHeader.vue` ergänzen

---

## Neuen API-Endpoint hinzufügen

1. Funktion in passendem Router (`api/songs.py`, `api/playback.py` oder `api/scan.py`)
2. Oder: Neue Datei `api/mein_router.py` anlegen und in `main.py` einbinden:

```python
from app.api import mein_router
app.include_router(mein_router.router)
```

3. Test via Swagger UI oder curl

---

## Häufige Entwicklerfragen

### Wie ändere ich das Farbschema?

Alle Farben sind CSS Custom Properties in `frontend/src/assets/global.css`:

```css
:root {
  --primary: #7c6ff7;   /* Lila – Haupt-Akzent */
  --accent:  #ffd700;   /* Gold  – Karaoke-Cursor */
  --bg:      #0d0d1a;   /* Dunkler Hintergrund */
  /* ... */
}
```

### Warum SQLite und kein PostgreSQL?

Für Heimgebrauch (HA-Addon, lokaler Server) ist SQLite ideal:
kein separater Datenbankserver, einfaches Backup (eine Datei).

SQLModel (das ORM) ist datenbankagnostisch – Migration zu PostgreSQL:
```python
# core/config.py
db_url: str = "postgresql+asyncpg://user:pass@localhost/notenleser"
```
+ `pip install asyncpg`

### Wie wird die OSMD-Lizenz gehandhabt?

OpenSheetMusicDisplay wird unter der MIT-Lizenz verwendet.
Keine kommerziellen Einschränkungen für den privaten Einsatz.

### Kann ich mehrere Stimmen (Chor, Klavierbegleitung) gleichzeitig abspielen?

Aktuell wird nur die erste Stimme für die Karaoke-Synchronisation verwendet.
Multi-Track-Unterstützung ist als zukünftiges Feature vorgesehen.
