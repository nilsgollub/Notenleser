# Notenleser – Android App (Flutter)

Eigenständige Android-App: Notenblatt fotografieren → Melodie abspielen → Karaoke.
Die Notenerkennung läuft über die **Claude Vision API** (Modell `claude-opus-4-7`),
die Wiedergabe und der Karaoke-Cursor laufen vollständig **offline auf dem Gerät**.

## Wie es funktioniert

```
Foto (Kamera/Galerie)
        │
        ▼
Claude Vision API  (claude-opus-4-7, High-Res-Vision)
        │  → strukturiertes JSON: Titel, Tonart, Takt, Tempo, Noten[]
        ▼
NoteEvent-Liste  ──►  WAV-Synthese (pure Dart, offline)  ──►  audioplayers
        │                                                          │
        └──────────────►  Piano-Roll-Karaoke-Cursor  ◄────────────┘
                                (folgt der Wiedergabeposition)
        │
        ▼
SQLite-Bibliothek (lokal auf dem Gerät)
```

- **OMR (Notenerkennung):** Das Foto wird base64-kodiert an die Claude Messages API
  geschickt. Per `output_config.format` (Structured Outputs) kommt garantiert
  valides JSON zurück. Opus 4.7 unterstützt hochauflösende Bilder (bis 2576 px),
  ideal für Notenblätter.
- **Audio:** Aus den Noten wird im Gerät eine WAV-Datei synthetisiert
  (Sinus + Obertöne + ADSR-Hüllkurve). Kein Soundfont, kein Server nötig.
- **Karaoke:** Eine Piano-Roll zeichnet die Melodie; ein goldener Cursor folgt der
  Audio-Position; die aktuell klingende Note leuchtet auf.
- **Bibliothek:** Alle erfassten Lieder werden lokal in SQLite gespeichert.

---

## Setup

### 1. Flutter installieren

[Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.19) und Android
Studio / Android SDK einrichten.

### 2. Projekt-Scaffolding erzeugen

Dieses Verzeichnis enthält nur die App-spezifischen Dateien (`lib/`, `pubspec.yaml`,
Manifest-Ergänzungen). Die Plattform-Gerüste (Gradle, Kotlin-Entry) erzeugst du
einmalig mit:

```bash
cd android-app
flutter create .          # ergänzt android/, fehlende Plattform-Dateien
```

`flutter create .` überschreibt **nicht** die vorhandenen `lib/`-Dateien oder die
`pubspec.yaml`. Danach die Manifest-Berechtigungen prüfen (siehe unten).

### 3. Abhängigkeiten holen & starten

```bash
flutter pub get
flutter run               # Gerät per USB oder Emulator
```

### 4. APK bauen

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Die APK auf das Smartphone kopieren und installieren (Installation aus unbekannten
Quellen erlauben).

---

## API-Key einrichten

Beim ersten Start fragt die App nach einem **Anthropic API-Key**
(`sk-ant-...`). Diesen bekommst du unter https://console.anthropic.com.
Er wird lokal in `shared_preferences` gespeichert und nur an `api.anthropic.com`
gesendet.

Pro Scan fallen API-Kosten an (ein Bild + etwas Output). Für ein einzelnes
Kinderlied sind das wenige Cent.

---

## Android-Berechtigungen

`flutter create .` erzeugt eine `AndroidManifest.xml`. Stelle sicher, dass diese
Zeilen enthalten sind (siehe `android/app/src/main/AndroidManifest.xml` in diesem
Repo als Vorlage):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

---

## Projektstruktur

```
android-app/
├── pubspec.yaml
├── lib/
│   ├── main.dart                  App-Einstieg, Routing, Theme
│   ├── theme.dart                 Dunkles Farbschema
│   ├── models/
│   │   ├── note_event.dart        Eine Note (Tonhöhe, Dauer, Takt) + MIDI/Frequenz
│   │   └── song.dart              Lied + Metadaten + Noten (JSON-Serialisierung)
│   ├── services/
│   │   ├── settings_service.dart  API-Key speichern/laden
│   │   ├── database_service.dart  SQLite-Bibliothek
│   │   ├── claude_service.dart    Claude Vision API (OMR)
│   │   └── audio_service.dart     WAV-Synthese + Wiedergabe + Karaoke-Timeline
│   ├── screens/
│   │   ├── library_screen.dart    Bibliothek + Suche
│   │   ├── scan_screen.dart       Foto aufnehmen + Fortschritt
│   │   ├── player_screen.dart     Player + Karaoke
│   │   └── settings_screen.dart   API-Key-Eingabe
│   └── widgets/
│       ├── song_tile.dart         Listeneintrag in der Bibliothek
│       ├── piano_roll.dart        Karaoke-Visualisierung (CustomPainter)
│       └── player_controls.dart   Play/Pause/Tempo/Karaoke-Schalter
└── android/app/src/main/AndroidManifest.xml   (Berechtigungs-Vorlage)
```
