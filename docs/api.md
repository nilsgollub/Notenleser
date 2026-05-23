# API-Referenz

Basis-URL: `http://<host>:8000`

Die interaktive Swagger-Dokumentation ist unter `/docs`, ReDoc unter `/redoc` verfügbar.

---

## Übersicht

| Methode | Pfad | Beschreibung |
|---|---|---|
| GET | `/health` | Health-Check |
| POST | `/scan/upload` | Notenbild hochladen und Scan starten |
| GET | `/scan/job/{job_id}` | Status eines Scan-Jobs abfragen |
| WS | `/scan/ws/{job_id}` | Echtzeit-Fortschritt per WebSocket |
| GET | `/songs/` | Alle Lieder (optional: Suche) |
| GET | `/songs/{id}` | Einzelnes Lied |
| DELETE | `/songs/{id}` | Lied löschen |
| GET | `/playback/{id}/audio` | WAV-Audio streamen |
| GET | `/playback/{id}/midi` | MIDI herunterladen |
| GET | `/playback/{id}/musicxml` | MusicXML herunterladen |
| GET | `/playback/{id}/image` | Scan-Bild abrufen |
| GET | `/playback/{id}/timing` | Karaoke-Timing-Daten |

---

## Health-Check

```http
GET /health
```

**Antwort:**
```json
{ "status": "ok", "version": "0.1.0" }
```

---

## Scan

### Notenbild hochladen

```http
POST /scan/upload
Content-Type: multipart/form-data
```

**Felder:**

| Feld | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `file` | `File` | ✓ | Notenbild (JPG, PNG, PDF) |
| `title` | `string` | — | Lied-Titel (wird aus Dateiname abgeleitet wenn leer) |

**Antwort `202 Accepted`:**
```json
{
  "job_id": 42,
  "song_id": 17
}
```

**Beispiel (curl):**
```bash
curl -X POST http://localhost:8000/scan/upload \
  -F "file=@noten.jpg" \
  -F "title=Hänschen Klein"
```

**Beispiel (JavaScript):**
```javascript
const form = new FormData()
form.append('file', fileObject)
form.append('title', 'Mein Lied')

const res = await fetch('/scan/upload', { method: 'POST', body: form })
const { job_id, song_id } = await res.json()
```

---

### Scan-Job-Status abfragen

```http
GET /scan/job/{job_id}
```

**Antwort:**
```json
{
  "id": 42,
  "song_id": 17,
  "status": "done",
  "error_message": null,
  "created_at": "2024-01-15T10:30:00"
}
```

**Status-Werte:**

| Wert | Bedeutung |
|---|---|
| `pending` | Job wartet auf Verarbeitung |
| `processing` | Verarbeitung läuft |
| `omr` | Notenerkennung (oemer) läuft |
| `metadata` | Metadaten werden extrahiert |
| `timing` | Karaoke-Timing wird berechnet |
| `midi` | MIDI wird erzeugt |
| `audio` | WAV-Audio wird gerendert |
| `done` | Fertig |
| `error:<Meldung>` | Fehler |

---

### WebSocket – Echtzeit-Fortschritt

```
WS /scan/ws/{job_id}
```

Der Server sendet JSON-Nachrichten bei jedem Schritt:

```json
{ "job_id": 42, "status": "omr" }
{ "job_id": 42, "status": "midi" }
{ "job_id": 42, "status": "done" }
```

**Beispiel (JavaScript):**
```javascript
const ws = new WebSocket(`ws://localhost:8000/scan/ws/${job_id}`)
ws.onmessage = (event) => {
  const { status } = JSON.parse(event.data)
  if (status === 'done') ws.close()
  if (status.startsWith('error')) console.error(status)
}
```

---

## Bibliothek

### Alle Lieder abrufen

```http
GET /songs/?q=<suchbegriff>
```

**Query-Parameter:**

| Parameter | Typ | Beschreibung |
|---|---|---|
| `q` | `string` | Freitext-Suche im Titel (optional) |

**Antwort:**
```json
[
  {
    "id": 17,
    "title": "Hänschen Klein",
    "composer": null,
    "key_signature": "C major",
    "time_signature": "3/4",
    "tempo_bpm": 120,
    "scan_image_path": "/data/uploads/abc123.jpg",
    "musicxml_path": "/data/musicxml/17.musicxml",
    "midi_path": "/data/audio/17.mid",
    "audio_path": "/data/audio/17.wav",
    "created_at": "2024-01-15T10:30:00",
    "updated_at": "2024-01-15T10:30:45"
  }
]
```

---

### Einzelnes Lied abrufen

```http
GET /songs/{id}
```

Gibt dasselbe Format wie oben zurück (einzelnes Objekt, kein Array).

**Fehler:** `404 Not Found` wenn ID nicht existiert.

---

### Lied löschen

```http
DELETE /songs/{id}
```

**Antwort:** `204 No Content`

> Hinweis: Löscht nur den Datenbank-Eintrag. Dateien in `/data` bleiben erhalten
> und können manuell entfernt werden.

---

## Wiedergabe & Download

### WAV-Audio streamen

```http
GET /playback/{id}/audio
```

Unterstützt HTTP Range Requests (für Seek im Browser).

**Response-Header:**
```
Content-Type: audio/wav
Content-Disposition: inline; filename="Hänschen Klein.wav"
```

**HTML5-Beispiel:**
```html
<audio controls src="/playback/17/audio"></audio>
```

---

### MIDI herunterladen

```http
GET /playback/{id}/midi
```

```
Content-Type: audio/midi
Content-Disposition: attachment; filename="Hänschen Klein.mid"
```

---

### MusicXML herunterladen

```http
GET /playback/{id}/musicxml
```

```
Content-Type: application/xml
Content-Disposition: attachment; filename="Hänschen Klein.musicxml"
```

MusicXML kann in MuseScore, Sibelius, Finale und anderen Notationsprogrammen geöffnet werden.

---

### Scan-Bild abrufen

```http
GET /playback/{id}/image
```

Liefert das Original-Scan-Bild (JPG oder PNG) zurück. Wird als Thumbnail in der Bibliothek verwendet.

---

### Karaoke-Timing-Daten

```http
GET /playback/{id}/timing
```

**Antwort:**
```json
{
  "bpm": 120.0,
  "total_duration": 32.5,
  "events": [
    {
      "time": 0.0,
      "duration": 0.5,
      "measure": 1,
      "pitches": ["C5"]
    },
    {
      "time": 0.5,
      "duration": 0.5,
      "measure": 1,
      "pitches": ["D5"]
    },
    {
      "time": 1.0,
      "duration": 1.0,
      "measure": 1,
      "pitches": ["E5", "G5"]
    }
  ]
}
```

**Felder:**

| Feld | Typ | Beschreibung |
|---|---|---|
| `bpm` | `float` | Tempo in Schlägen pro Minute |
| `total_duration` | `float` | Gesamtdauer des Stücks in Sekunden |
| `events[].time` | `float` | Start-Zeit in Sekunden ab Anfang |
| `events[].duration` | `float` | Dauer der Note in Sekunden |
| `events[].measure` | `int` | Taktnummer (1-basiert) |
| `events[].pitches` | `string[]` | Tonhöhen in wissenschaftlicher Notation (z. B. `"C5"`, `"F#4"`) |

**Fehler:** `404` wenn noch kein Timing berechnet wurde (Scan noch nicht abgeschlossen).

---

## Fehlercodes

| HTTP-Code | Bedeutung |
|---|---|
| `202` | Scan-Job akzeptiert, Verarbeitung läuft |
| `204` | Erfolgreich gelöscht |
| `404` | Ressource nicht gefunden |
| `422` | Ungültige Anfrage (fehlende Felder) |
| `500` | Interner Server-Fehler |

Bei `500`-Fehlern liefert der Response-Body:
```json
{ "detail": "Fehlermeldung" }
```
