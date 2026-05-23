# Installations-Anleitung

## Inhaltsverzeichnis

1. [Variante A – Docker Compose (empfohlen)](#variante-a--docker-compose-empfohlen)
2. [Variante B – Native Installation](#variante-b--native-installation)
3. [Variante C – Produktion (Single-Container)](#variante-c--produktion-single-container)
4. [OMR-Engine aktivieren](#omr-engine-aktivieren)
5. [FluidSynth & Soundfonts](#fluidsynth--soundfonts)
6. [Datenpersistenz](#datenpersistenz)
7. [Häufige Probleme](#häufige-probleme)

---

## Variante A – Docker Compose (empfohlen)

Die einfachste Methode. Erfordert nur Docker.

```bash
git clone https://github.com/nilsgollub/notenleser.git
cd notenleser

# Starten (Dev-Mode mit Hot-Reload)
docker-compose up

# Im Hintergrund starten
docker-compose up -d

# Logs anzeigen
docker-compose logs -f backend
docker-compose logs -f frontend

# Stoppen
docker-compose down
```

**Zugangspunkte:**

| Dienst | URL |
|---|---|
| Web-Oberfläche | http://localhost:5173 |
| API-Dokumentation | http://localhost:8000/docs |
| API-Schema (ReDoc) | http://localhost:8000/redoc |

**Im Dev-Mode** läuft die OMR-Engine im `mock`-Modus (gibt ein Testlied zurück, kein GPU nötig).
Für echte Notenerkennung → [OMR-Engine aktivieren](#omr-engine-aktivieren).

---

## Variante B – Native Installation

### System-Abhängigkeiten (Ubuntu/Debian)

```bash
sudo apt-get update && sudo apt-get install -y \
    python3.12 python3-pip \
    libgl1 libglib2.0-0 \
    fluidsynth fluid-soundfont-gm \
    ffmpeg \
    nodejs npm
```

### Backend

```bash
cd backend

# Virtuelle Umgebung anlegen
python3 -m venv .venv
source .venv/bin/activate

# Abhängigkeiten installieren
pip install -r requirements.txt

# Daten-Verzeichnis anlegen
mkdir -p /data/{uploads,audio,musicxml,db}

# Starten
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Frontend

```bash
cd frontend

# Abhängigkeiten installieren
npm install

# Dev-Server starten (Vite mit API-Proxy)
npm run dev

# Oder: Produktion bauen
npm run build
# → dist/ kann mit einem beliebigen Webserver ausgeliefert werden
```

---

## Variante C – Produktion (Single-Container)

Das Backend liefert das gebaute Frontend direkt als statische Dateien aus.
Kein separater Frontend-Container nötig.

```bash
# Frontend bauen
cd frontend
npm ci
npm run build
cd ..

# Backend-Image bauen (enthält das gebaute Frontend)
docker build -t notenleser-backend ./backend

# Container starten
docker run -d \
    --name notenleser \
    -p 8000:8000 \
    -v $(pwd)/data:/data \
    -e OMR_ENGINE=oemer \
    notenleser-backend
```

Die App ist dann unter http://\<server\>:8000 erreichbar.

---

## OMR-Engine aktivieren

Standardmäßig läuft der **Mock-Modus** (gibt immer dasselbe Testlied zurück).
Für echte Notenerkennung wird `oemer` benötigt.

### oemer installieren

oemer benötigt PyTorch. Empfohlen auf einem System mit mindestens 4 GB RAM:

```bash
# CPU-only (langsamer, aber überall verfügbar)
pip install oemer

# Mit CUDA-GPU (schneller)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
pip install oemer
```

### Engine umschalten

```bash
# docker-compose
OMR_ENGINE=oemer docker-compose up

# .env-Datei im backend/-Verzeichnis
echo "OMR_ENGINE=oemer" >> backend/.env
```

### Verarbeitungszeit

| Hardware | Typische Scan-Zeit |
|---|---|
| CPU (4 Kerne) | 30–120 Sekunden |
| GPU (CUDA) | 5–15 Sekunden |
| Mock | < 1 Sekunde |

---

## FluidSynth & Soundfonts

FluidSynth wandelt MIDI in hochwertige WAV-Audio-Dateien um.

### Installation

```bash
# Ubuntu/Debian
sudo apt-get install fluidsynth fluid-soundfont-gm

# macOS
brew install fluidsynth

# Alpine (Docker / HA-Addon)
apk add fluidsynth soundfont-fluid-r3-gm
```

### Alternative Soundfonts

Für bessere Klangqualität kann eine höherwertige Soundfont verwendet werden:

```bash
# GeneralUser GS (klein, gut)
wget https://schristiancollins.com/generaluser.php -O /opt/GeneralUser.sf2

# Yamaha Disklavier (groß, sehr gut)
# → Kommerziell, eigene Lizenz erforderlich
```

```dotenv
# backend/.env
SOUNDFONT_PATH=/opt/GeneralUser.sf2
```

### Fallback ohne FluidSynth

Falls FluidSynth nicht verfügbar ist, wird kein WAV erzeugt. Das Frontend wechselt
automatisch in den **Browser-Synth-Modus** (Tone.js) – die Wiedergabe funktioniert
weiterhin, klingt aber synthetischer.

---

## Datenpersistenz

Alle Laufzeit-Daten werden unter `DATA_DIR` (Standard: `/data`) gespeichert:

```
/data/
├── db/
│   └── notenleser.db        ← SQLite-Datenbank
├── uploads/
│   └── <uuid>.jpg           ← Original-Scan-Bilder
├── musicxml/
│   └── <song_id>.musicxml   ← Erkannte Noten
└── audio/
    ├── <song_id>.mid        ← MIDI-Datei
    ├── <song_id>.wav        ← Gerendertes Audio
    └── <song_id>_timing.json← Timing für Karaoke
```

**Backup:**
```bash
# Alles sichern
tar czf notenleser-backup.tar.gz data/

# Wiederherstellen
tar xzf notenleser-backup.tar.gz
```

---

## Häufige Probleme

### „oemer fehlgeschlagen" im Log

- Bild zu klein oder unscharf? → Mindestauflösung: 1000 × 700 px
- Zu wenig RAM? oemer braucht ≥ 2 GB frei
- Nur ein Liniensystem pro Seite erkennbar – mehrseitige PDFs ggf. aufteilen

### Kein Audio im Browser

- Prüfen ob `audio_path` im Song-Objekt gesetzt ist (API: `GET /songs/<id>`)
- Falls leer: FluidSynth-Log prüfen (`docker-compose logs backend | grep FluidSynth`)
- Soundfont-Pfad korrekt? → `SOUNDFONT_PATH` prüfen

### WebSocket verbindet nicht

- Beim Einsatz hinter einem Reverse Proxy (nginx, Traefik) müssen
  WebSocket-Upgrades weitergeleitet werden:

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

### Port 8000 bereits belegt

```bash
# Anderen Port verwenden
docker run -p 9000:8000 notenleser-backend
# oder in docker-compose.yml "8000:8000" → "9000:8000" ändern
```
