# Karaoke-Modus

Der Karaoke-Modus lässt einen goldenen Cursor durch das Notenblatt wandern, der
exakt mit der Melodie-Wiedergabe synchronisiert ist.

---

## Aktivieren

1. Lied in der Bibliothek antippen → Player öffnet sich
2. Auf das **Mikrofon-Symbol** in der Steuerleiste tippen  
   (oder bei MIDI-Modus: **★ Karaoke**-Schaltfläche)
3. Auf **Play** drücken

Der goldene Cursor beginnt bei der ersten Note und wandert mit der Musik.

---

## Wie es funktioniert

### Schritt 1 – Timing wird beim Scan berechnet

Während der Scan-Verarbeitung extrahiert `music21` für jede Note:

- **Wann** sie im Stück beginnt (Sekunden ab Anfang)
- **Wie lange** sie dauert (Sekunden)
- In welchem **Takt** sie steht
- Welche **Tonhöhe(n)** sie hat

Dieses Timing-Array wird als JSON neben der Audiodatei gespeichert.

### Schritt 2 – Notenblatt wird gerendert

[OpenSheetMusicDisplay (OSMD)](https://opensheetmusicdisplay.org/) rendert die
MusicXML-Datei als SVG direkt im Browser. OSMD stellt einen eingebauten Cursor zur
Verfügung, der die aktuelle Note hervorhebt und das Notenblatt automatisch scrollt.

### Schritt 3 – Sync-Loop

Sobald die Wiedergabe startet, läuft eine Schleife mit `requestAnimationFrame`
(~60 Mal pro Sekunde):

```
Aktuelle Abspielzeit abfragen
        │
        ▼
Timing-Array durchsuchen:
Welcher Ton gehört zu dieser Zeit?
        │
        ▼
OSMD-Cursor auf diese Position setzen
        │
        ▼
Nächsten Frame abwarten → repeat
```

Die Genauigkeit liegt bei < 20 ms (ein halbes Frame bei 60 fps).

---

## Seek-Toleranz

Wenn der Nutzer im Fortschrittsbalken springt, erkennt der Sync-Loop automatisch
eine Abweichung von mehr als 2 Noten und setzt den Cursor auf die korrekte Position zurück.

---

## Wiedergabe-Modi

### Modus 1 – WAV-Audio (Standard)

Wenn FluidSynth beim Scan ein WAV erzeugt hat:

```
HTML5 <audio> Element
    ↓ timeupdate / requestAnimationFrame
OSMD Cursor-Sync
```

Der Vorteil: Die WAV-Datei klingt wie ein echtes Piano (hängt von der Soundfont ab).

### Modus 2 – Browser-Synthesizer (Fallback)

Wenn kein WAV verfügbar ist (FluidSynth nicht installiert oder Soundfont fehlt),
übernimmt [Tone.js](https://tonejs.github.io/) die Wiedergabe:

```javascript
// Alle Noten werden vorab in den Tone.js Transport eingeplant:
events.forEach(ev => {
    Tone.Transport.schedule(time => {
        synth.triggerAttackRelease(ev.pitches, ev.duration, time)
    }, ev.time)
})

// OSMD-Cursor läuft parallel per requestAnimationFrame
```

Der Browser-Synth klingt synthetischer (Dreieck-Welle), ist aber überall verfügbar
ohne Server-Abhängigkeiten.

---

## Tempo-Anpassung im Karaoke-Modus

Der Tempo-Slider (40 % – 150 %) ändert die `playbackRate` des `<audio>`-Elements.
Der Karaoke-Cursor passt sich automatisch an, da er immer `audio.currentTime` liest
(nicht eine interne Uhr). Bei 50 % Tempo läuft der Cursor also halb so schnell.

---

## Cursor-Design

Der OSMD-Cursor ist als goldene vertikale Linie implementiert und pulsiert sanft:

```css
/* OSMD rendert den Cursor als SVG-Element mit Klasse .vf-cursor */
.vf-cursor {
    opacity: 0.55;
    animation: cursor-pulse 1s ease-in-out infinite;
}
@keyframes cursor-pulse {
    0%, 100% { opacity: 0.55; }
    50%       { opacity: 0.85; }
}
```

Farbe und Transparenz werden beim Initialisieren von OSMD gesetzt:

```javascript
new OpenSheetMusicDisplay(container, {
    cursorOptions: [{ type: 0, color: '#ffd700', alpha: 0.55 }],
    followCursor: true,  // Auto-Scroll
})
```

---

## Bekannte Einschränkungen

| Einschränkung | Ursache | Workaround |
|---|---|---|
| Wiederholungszeichen werden nicht beachtet | music21 linearisiert den Score | Stück ohne Wiederholungen einscannen |
| Auftakt verschiebt Timing | oemer-Erkennung ungenau | Manuelles Offset-Korrektur (geplant) |
| Akkorde zählen als eine OSMD-Cursor-Position | OSMD-Architektur | – |
| Sehr schnelle Läufe (>8 Noten/Sek.) sehen ruckartig aus | 60-fps-Limit | – |

---

## Feintuning

Für Stücke bei denen das Timing leicht verschoben wirkt, kann ein globaler Offset
gesetzt werden (zukünftiges Feature). Aktuell kann die BPM-Angabe in der MusicXML
manuell angepasst werden:

```xml
<!-- In der .musicxml-Datei unter /data/musicxml/<id>.musicxml: -->
<direction>
  <direction-type>
    <metronome>
      <beat-unit>quarter</beat-unit>
      <per-minute>108</per-minute>  <!-- ← BPM anpassen -->
    </metronome>
  </direction-type>
</direction>
```

Nach Änderung der MusicXML muss das Timing neu berechnet werden – das geht
aktuell über einen erneuten Scan oder direkt via API:

```bash
# Timing-JSON manuell löschen und neu generieren (geplantes Feature)
```
