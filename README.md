# Notenleser

> Notenblatt fotografieren – Melodie abspielen. Mit Karaoke-Modus und Lied-Bibliothek.

Android-App (Flutter) zur Notenerkennung. Drei Erkennungsmodi stehen zur Wahl: Claude, Gemini oder ein lokales OMR-Backend als Home Assistant Addon.

---

## Wie es funktioniert

```
Foto (Kamera/Galerie)
        │
        ▼
┌───────────────────────────────────────────────────┐
│  Erkennungsmodus (in den Einstellungen wählbar)   │
│                                                   │
│  A) Claude Vision API  (claude-opus-4-7)          │
│  B) Gemini Vision API  (gemini-1.5-flash, gratis) │
│  C) Eigener Server     (oemer, lokal/offline)     │
└───────────────────────────────────────────────────┘
        │  → ABC-Notation (A/B) oder JSON (C)
        ▼
NoteEvent-Liste  ──►  WAV-Synthese (offline, Dart)  ──►  audioplayers
        │                                                       │
        └────────────►  Piano-Roll-Karaoke-Cursor  ◄───────────┘
        │
        ▼
SQLite-Bibliothek (lokal auf dem Gerät)
```

**Notenerkennung:**
- Claude und Gemini geben die Noten als **ABC-Notation** zurück – ein kompaktes Textformat, das Sprachmodelle zuverlässiger als JSON produzieren.
- Der lokale Server (oemer) liefert JSON direkt vom Pi.

**Audio:** WAV-Synthese im Gerät (Sinus + Obertöne + ADSR). Kein Soundfont, kein Internet nötig.

**Karaoke:** Piano-Roll mit goldenem Cursor, der der Audiowiedergabe folgt.

**Bibliothek:** Alle Lieder lokal in SQLite.

---

## App-Setup

### 1. Flutter installieren

[Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.19) und Android SDK einrichten.

### 2. Abhängigkeiten holen & starten

```bash
cd android-app
flutter pub get
flutter run
```

### 3. APK bauen

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

---

## Erkennungsmodi einrichten

### Claude (Standard)

API-Key unter https://console.anthropic.com erstellen (`sk-ant-...`).  
In der App: Einstellungen → Claude → Key eingeben.

### Gemini (kostenlos)

API-Key unter https://aistudio.google.com erstellen.  
In der App: Einstellungen → Gemini → Key eingeben.  
Modell wählbar: `gemini-1.5-flash` (kostenlos) oder `gemini-1.5-pro`.

### Eigener Server (lokal & offline)

Lokales OMR-Backend als Home Assistant Addon (siehe unten).  
In der App: Einstellungen → Server → URL eingeben (z. B. `http://homeassistant.local:8765`).  
Verbindungstest-Button prüft die Erreichbarkeit.  
Verarbeitungszeit auf Raspberry Pi 4: ca. 2–5 Minuten.

---

## HA Addon – Notenleser OMR

Lokales Notenerkennung-Backend auf Basis von [oemer](https://github.com/BreezeWhite/oemer) + [music21](https://web.mit.edu/music21/), gehostet als Home Assistant Addon.

### Installation

1. HA → Einstellungen → Add-ons → Add-on Store → ⋮ → Repositories
2. URL eintragen: `https://github.com/nilsgollub/notenleser`
3. „Notenleser OMR" installieren und starten
4. Port 8765 ist nach dem Start erreichbar

### API

| Endpunkt | Methode | Beschreibung |
|----------|---------|--------------|
| `/health` | GET | Statuscheck → `{"status": "ok"}` |
| `/recognize` | POST | Notenblatt erkennen (Multipart: `image`) |

```bash
# Statuscheck
curl http://homeassistant.local:8765/health

# Notenblatt erkennen
curl -F "image=@notenblatt.jpg" http://homeassistant.local:8765/recognize | jq .
```

**Antwortformat `/recognize`:**
```json
{
  "title": "Hänschen klein",
  "composer": "",
  "key": "G-Dur",
  "time_signature": "3/4",
  "tempo_bpm": 120,
  "notes": [
    {"pitch": "G4", "duration_beats": 1.0, "measure": 1},
    {"pitch": "REST", "duration_beats": 0.5, "measure": 2}
  ]
}
```

### Addon-Ordner

```
notenleser-omr/
├── config.yaml          HA-Addon-Metadaten (Port 8765)
├── build.yaml           Docker-Build-Konfiguration
├── Dockerfile           python:3.11-slim-bookworm
├── run.sh               Startet uvicorn
└── app/
    ├── main.py          FastAPI: POST /recognize, GET /health
    ├── omr.py           oemer-Aufruf + MusicXML → JSON (music21)
    └── requirements.txt
```

---

## Projektstruktur

```
android-app/
├── pubspec.yaml
└── lib/
    ├── main.dart
    ├── theme.dart
    ├── models/
    │   ├── note_event.dart        Eine Note (Tonhöhe, Dauer, Takt)
    │   └── song.dart              Lied + Metadaten
    ├── services/
    │   ├── omr_service.dart       Interface + OmrProvider-Enum
    │   ├── claude_service.dart    Claude Vision API (ABC-Notation)
    │   ├── gemini_service.dart    Gemini Vision API (ABC-Notation)
    │   ├── backend_service.dart   Lokales OMR-Backend (HTTP)
    │   ├── abc_parser.dart        ABC-Notation → Song
    │   ├── settings_service.dart  Provider, API-Keys, Backend-URL
    │   ├── database_service.dart  SQLite-Bibliothek
    │   └── audio_service.dart     WAV-Synthese + Wiedergabe
    ├── screens/
    │   ├── library_screen.dart
    │   ├── scan_screen.dart
    │   ├── player_screen.dart
    │   └── settings_screen.dart
    └── widgets/
        ├── song_tile.dart
        ├── piano_roll.dart
        ├── player_controls.dart
        └── lyrics_view.dart

notenleser-omr/          HA Addon (lokales OMR-Backend)
repository.yaml          HA Custom Repository Metadaten
```
