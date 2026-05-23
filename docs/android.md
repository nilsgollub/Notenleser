# Notenleser auf Android installieren

Notenleser ist eine Progressive Web App (PWA) – sie kann wie eine native App auf
dem Android-Homescreen installiert werden, ohne App Store.

---

## Installation als PWA

### Voraussetzungen

- Android 8.0 oder neuer
- Google Chrome oder Edge (empfohlen)
- Notenleser-Server im lokalen Netzwerk erreichbar

### Schritte

1. **Chrome öffnen** und zur Notenleser-URL navigieren:
   ```
   http://<server-ip>:5173
   ```
   oder in Produktion:
   ```
   http://<server-ip>:8000
   ```

2. **Installationsaufforderung** – Chrome zeigt unten ein Banner:
   *„Notenleser zum Startbildschirm hinzufügen"*  
   → **Hinzufügen** antippen

   Falls kein Banner erscheint:
   - Chrome-Menü (⋮) → **Zum Startbildschirm hinzufügen**

3. Die App erscheint auf dem Homescreen mit eigenem Icon.

4. Beim nächsten Öffnen startet sie im **Vollbild-Modus** ohne Browser-Leiste.

---

## Kamera-Zugriff

Die App nutzt die Rück-Kamera des Smartphones direkt zum Scannen:

1. Beim ersten Scan auf **Kamera öffnen** tippen
2. Chrome fragt nach Kamera-Erlaubnis → **Zulassen**
3. Die Kamera öffnet sich im Standard-Fotoapp-Modus
4. Foto aufnehmen → wird automatisch in der App weiterverarbeitet

**Tipp für beste Ergebnisse:**
- Notenblatt auf flacher Unterlage auslegen
- Gleichmäßige Beleuchtung (kein Gegenlicht, keine Schatten)
- Blatt vollständig im Bild (mit etwas Rand)
- Kamera parallel zum Blatt halten (nicht schräg)
- Mindestauflösung: 8 MP (bei modernen Smartphones kein Problem)

---

## Offline-Nutzung

Die PWA cacht alle App-Ressourcen (JavaScript, CSS, Bilder) via Service Worker.

| Funktion | Offline verfügbar? |
|---|---|
| Bibliothek-Ansicht | ✓ (gecachte Songs) |
| Notenblatt anzeigen | ✓ (gecachtes MusicXML) |
| Audio abspielen | ✓ (gecachtes WAV / Browser-Synth) |
| Neues Lied scannen | ✗ (Server-Verbindung nötig) |

---

## Ton-Einstellungen

Da die Wiedergabe im Browser stattfindet:

- **Lautstärke**: über die Hardware-Lautstärketaste regeln
- **Kopfhörer**: werden automatisch erkannt
- **Bluetooth**: über Android-Audio-Routing wie gewohnt

Falls der Ton stumm bleibt: Sicherstellen dass der Ton-Modus nicht auf „Stumm" steht
(Klingelton-Taste).

---

## Tipps für den Alltag

### Kinderlied schnell vorspielen

1. Bibliothek öffnen → Lied antippen
2. Play → Karaoke-Modus aktivieren
3. Tempo auf 70 % reduzieren für Einübphase

### Neue Lieder unterwegs hinzufügen

Solange das Smartphone im gleichen WLAN wie der Server ist:

1. Scan-Tab öffnen
2. Foto aufnehmen oder aus Galerie wählen
3. Server verarbeitet das Bild (~1 Min. auf schwacher Hardware)
4. Lied erscheint in der Bibliothek

### Teilen mit der Familie

Da Notenleser ein Server im Heimnetz ist, können **alle Geräte im WLAN**
gleichzeitig darauf zugreifen – kein separates Konto nötig.

---

## Bekannte Einschränkungen

| Einschränkung | Beschreibung |
|---|---|
| Kein App-Store | Muss manuell über den Browser installiert werden |
| Server muss erreichbar sein | Für neues Scannen braucht das Gerät WLAN-Zugang |
| iOS (iPhone/iPad) | PWA funktioniert, Kamera-Capture kann abweichen |
| Hintergrund-Wiedergabe | Wenn der Bildschirm gesperrt wird, stoppt die Wiedergabe (Browser-Einschränkung) |

---

## Alternative: Native App mit Capacitor

Für vollständigen nativen App-Zugang (App Store, Hintergrund-Audio, Push-Notifications)
kann das Vue.js-Frontend mit [Capacitor](https://capacitorjs.com/) in eine APK verpackt werden:

```bash
cd frontend
npm install @capacitor/core @capacitor/cli @capacitor/android

# Capacitor initialisieren
npx cap init Notenleser de.notenleser.app

# Konfigurieren (capacitor.config.json):
{
  "appId": "de.notenleser.app",
  "appName": "Notenleser",
  "webDir": "dist",
  "server": { "url": "http://<server-ip>:8000" }
}

# Android-Projekt erzeugen
npm run build
npx cap add android
npx cap sync android

# In Android Studio öffnen und APK bauen
npx cap open android
```

Dies ist als optionaler nächster Schritt vorgesehen und noch nicht in der
Standard-Implementierung enthalten.
