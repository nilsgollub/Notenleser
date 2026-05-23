# Notenleser

> Notenblatt fotografieren – Melodie abspielen. Inkl. Karaoke-Modus und Lied-Bibliothek.

---

## Inhaltsverzeichnis

1. [Funktionen](#funktionen)
2. [Schnellstart](#schnellstart)
3. [Plattformen](#plattformen)
4. [Architektur-Überblick](#architektur-überblick)
5. [Konfiguration](#konfiguration)
6. [Weiterführende Dokumentation](#weiterführende-dokumentation)

---

## Funktionen

| Feature | Beschreibung |
|---|---|
| **Scan** | Notenblatt per Kamera oder Datei-Upload erfassen |
| **OMR** | Automatische Notenerkennung (Optical Music Recognition) via *oemer* |
| **Wiedergabe** | WAV-Audio (FluidSynth) oder Browser-Synthesizer (Tone.js) |
| **Karaoke-Modus** | Goldener Cursor folgt der Melodie im Notenblatt in Echtzeit |
| **Tempo-Kontrolle** | Wiedergabegeschwindigkeit von 40 % bis 150 % |
| **Bibliothek** | Alle Lieder mit Metadaten (Tonart, Takt, Tempo, Datum) |
| **Export** | MIDI, MusicXML und WAV herunterladen |
| **PWA** | Installierbar auf Android wie eine native App |
| **Home Assistant** | Als Addon mit Ingress-Panel integrierbar |

---

## Schnellstart

### Voraussetzungen

- [Docker](https://docs.docker.com/get-docker/) + [Docker Compose](https://docs.docker.com/compose/install/)

### Starten

```bash
git clone https://github.com/nilsgollub/notenleser.git
cd notenleser
docker-compose up
```

| Dienst | URL |
|---|---|
| Frontend | http://localhost:5173 |
| API (Swagger) | http://localhost:8000/docs |

### Erstes Lied scannen

1. Browser öffnen → http://localhost:5173
2. Unten auf **Scan** (Kamera-Symbol) tippen
3. Notenbild hochladen oder Kamera öffnen
4. Warten bis die Fortschrittsanzeige „Fertig!" zeigt
5. Auf **Jetzt anhören** tippen
6. Player öffnet sich → **★ Karaoke** aktivieren

---

## Plattformen

### Android (PWA)

1. http://\<server-ip\>:5173 in Chrome öffnen
2. Menü → *Zum Startbildschirm hinzufügen*
3. App erscheint wie eine native Anwendung

→ Ausführliche Anleitung: [docs/android.md](docs/android.md)

### Home Assistant Addon

1. Repository zur HA-Addon-Store-Liste hinzufügen
2. Addon *Notenleser* installieren und starten
3. Panel erscheint automatisch in der Seitenleiste

→ Ausführliche Anleitung: [docs/homeassistant.md](docs/homeassistant.md)

---

## Architektur-Überblick

```
┌─────────────────────────────────────────────────────────────┐
│                  Frontend  (Vue 3 PWA)                      │
│   Scan  ──►  Fortschritt  ──►  Player  ──►  Bibliothek      │
│                        ▲  Karaoke-Cursor  ▲                 │
└──────────────────────┬──────────────────────────────────────┘
                       │  REST + WebSocket
┌──────────────────────▼──────────────────────────────────────┐
│                 Backend  (FastAPI / Python)                  │
│                                                             │
│   Upload ──► OMR (oemer) ──► music21 ──► FluidSynth         │
│               [MusicXML]     [MIDI]      [WAV + Timing]     │
│                                                             │
│   SQLite-Bibliothek  |  /data  (Bilder, Audio, XML)         │
└─────────────────────────────────────────────────────────────┘
```

→ Detaillierte Architektur-Entscheidungen: [docs/architecture.md](docs/architecture.md)

---

## Konfiguration

Alle Einstellungen können per Umgebungsvariable oder `.env`-Datei im `backend/`-Verzeichnis gesetzt werden.

| Variable | Standard | Beschreibung |
|---|---|---|
| `OMR_ENGINE` | `mock` | `oemer` für Produktion, `mock` für Entwicklung |
| `DATA_DIR` | `/data` | Basis-Verzeichnis für alle Laufzeit-Daten |
| `SOUNDFONT_PATH` | `/usr/share/sounds/sf2/FluidR3_GM.sf2` | Pfad zur FluidSynth-Soundfont |
| `DB_URL` | `sqlite+aiosqlite:////data/db/notenleser.db` | Datenbank-URL |

**Beispiel `.env`:**
```dotenv
OMR_ENGINE=oemer
DATA_DIR=/mnt/music-data
SOUNDFONT_PATH=/opt/soundfonts/Steinway.sf2
```

---

## Weiterführende Dokumentation

| Dokument | Inhalt |
|---|---|
| [docs/setup.md](docs/setup.md) | Detaillierte Installationsanleitung (Docker, nativ, Produktion) |
| [docs/architecture.md](docs/architecture.md) | Technische Architektur-Entscheidungen |
| [docs/api.md](docs/api.md) | Vollständige API-Referenz |
| [docs/karaoke.md](docs/karaoke.md) | Karaoke-Modus: Funktionsweise und Feintuning |
| [docs/homeassistant.md](docs/homeassistant.md) | Home Assistant Addon installieren |
| [docs/android.md](docs/android.md) | Als Android-App installieren |
| [docs/development.md](docs/development.md) | Entwicklungsumgebung aufsetzen, Beitragen |
