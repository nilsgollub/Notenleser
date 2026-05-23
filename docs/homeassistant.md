# Home Assistant Addon

Notenleser lässt sich als Home Assistant Addon installieren und erscheint dann
als eigenes Panel in der HA-Seitenleiste.

---

## Voraussetzungen

- Home Assistant OS oder Supervised (nicht Home Assistant Container)
- HA-Version ≥ 2023.1
- Mindestens 512 MB freier RAM (für Backend + oemer ~2 GB empfohlen)

---

## Installation

### Schritt 1 – Repository hinzufügen

1. In HA: **Einstellungen → Add-ons → Add-on-Store** öffnen
2. Drei-Punkte-Menü oben rechts → **Repositories**
3. URL eingeben:
   ```
   https://github.com/nilsgollub/notenleser
   ```
4. **Hinzufügen** klicken

### Schritt 2 – Addon installieren

1. Im Add-on-Store nach **Notenleser** suchen
2. Auf das Addon klicken → **Installieren**
3. Warten bis der Download abgeschlossen ist (~500 MB – ~3 GB je nach oemer)

### Schritt 3 – Konfigurieren

Im Addon-Tab **Konfiguration**:

```yaml
omr_engine: mock   # "mock" zum Testen, "oemer" für echte Notenerkennung
```

| Option | Werte | Beschreibung |
|---|---|---|
| `omr_engine` | `mock` \| `oemer` | OMR-Backend |

### Schritt 4 – Starten

1. Tab **Info** → **Starten**
2. **In der Seitenleiste anzeigen** aktivieren (falls nicht automatisch)
3. In der HA-Seitenleiste erscheint **Notenleser**

---

## Ingress

Das Addon nutzt HA Ingress – die Web-Oberfläche wird über HA's Authentifizierung
proxied. Es wird kein zusätzlicher Port geöffnet.

Die interne URL (für direkten Zugriff z. B. aus dem lokalen Netz):
```
http://<ha-ip>:8000
```

---

## Daten-Persistenz

Alle Daten werden im HA-Addon-Config-Volume gespeichert:

```
/addon_configs/notenleser/
├── db/notenleser.db
├── uploads/
├── musicxml/
└── audio/
```

Diese Daten überleben Addon-Updates und Neustarts.

**Backup:** HA's eingebautes Backup-System sichert Addon-Config-Volumes automatisch mit.

---

## OMR auf Home Assistant

### Mock-Modus (Standard)

Kein GPU, kein PyTorch. Jeder Scan gibt ein eingebautes Testlied zurück.
Ideal zum Ausprobieren der App ohne Rechenaufwand.

### oemer auf Raspberry Pi 4/5

```yaml
omr_engine: oemer
```

- Verarbeitungszeit: **2–5 Minuten** pro Scan (CPU-only)
- RAM-Bedarf: ~3 GB während der Erkennung
- **Empfehlung:** Nur auf Pi 4 mit 4 GB RAM oder Pi 5 verwenden

### oemer auf x86 (NUC, Mini-PC)

- Verarbeitungszeit: **30–90 Sekunden** (CPU)
- Mit GPU (z. B. Intel Arc, NVIDIA): **5–15 Sekunden**

---

## Troubleshooting

### Addon startet nicht

```bash
# Logs anzeigen in HA
Einstellungen → Add-ons → Notenleser → Log
```

Häufige Ursachen:
- Port 8000 bereits belegt → anderen Port in der Netzwerk-Konfiguration wählen
- Zu wenig RAM → oemer erfordert ≥ 2 GB; `mock` als Engine verwenden

### Panel erscheint nicht in der Seitenleiste

1. Addon-Seite → Tab **Info**
2. **In der Seitenleiste anzeigen** muss aktiviert sein
3. Seite neu laden (Strg+F5)

### Audio wird nicht abgespielt

Das Addon enthält FluidSynth und die `FluidR3_GM.sf2`-Soundfont.
Falls kein Audio erzeugt wird:

1. Log prüfen: `FluidSynth` Fehlermeldungen?
2. Soundfont vorhanden? Pfad im Log: `SOUNDFONT_PATH=/usr/share/sounds/sf2/...`
3. Im Zweifel: Browser-Synth (Tone.js) übernimmt automatisch

### Noten werden falsch erkannt

- Bild-Qualität erhöhen (mind. 300 dpi)
- Hellen Hintergrund, guten Kontrast sicherstellen
- Bild gerade ausrichten (kein starker Winkel)
- `oemer` statt `mock` als Engine verwenden

---

## Update

Addon-Updates erscheinen automatisch im HA Add-on-Store.
Nach einem Update müssen Daten nicht migriert werden – das Datenbankschema
ist abwärtskompatibel.

---

## Deinstallation

1. **Einstellungen → Add-ons → Notenleser → Deinstallieren**
2. Optional: Daten löschen unter `/addon_configs/notenleser/`

```bash
# SSH-Zugang zu HA OS:
rm -rf /addon_configs/notenleser/
```
