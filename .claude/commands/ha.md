# Home Assistant – Verbindung und Steuerung

Wenn dieser Befehl aufgerufen wird, hast du Zugriff auf die Home Assistant Instanz
des Nutzers. Verbindungsdaten stehen als Umgebungsvariablen bereit:

- `$HA_URL`   – Basis-URL, z. B. `http://192.168.1.100:8123`
- `$HA_TOKEN` – Long-Lived Access Token (unter HA → Profil → Langlebige Zugriffstoken)

## Authentifizierung

Alle REST-API-Aufrufe brauchen diesen Header:
```
Authorization: Bearer $HA_TOKEN
Content-Type: application/json
```

## Wichtige Endpunkte

| Aktion | Methode + Pfad |
|--------|----------------|
| Alle Entitäten | `GET $HA_URL/api/states` |
| Eine Entität | `GET $HA_URL/api/states/{entity_id}` |
| Service aufrufen | `POST $HA_URL/api/services/{domain}/{service}` |
| Konfiguration | `GET $HA_URL/api/config` |
| Addon-Info | `GET $HA_URL/api/hassio/addons` (Supervisor) |
| Addon-Logs | `GET $HA_URL/api/hassio/addons/{slug}/logs` |

## Beispiele

Alle Entitäten auflisten:
```bash
curl -s -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/states" | jq '.[].entity_id'
```

Licht einschalten:
```bash
curl -s -X POST \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "light.wohnzimmer"}' \
  "$HA_URL/api/services/light/turn_on"
```

Notenleser-OMR-Addon-Logs abrufen:
```bash
curl -s -H "Authorization: Bearer $HA_TOKEN" \
  "$HA_URL/api/hassio/addons/notenleser_omr/logs"
```

## Notenleser-OMR-Addon

Das OMR-Backend läuft unter `$HA_URL` auf Port 8765 (direkt, nicht über HA-API):
- Health-Check: `curl http://${HA_HOST}:8765/health`
- Notenblatt scannen: `curl -F "image=@test.jpg" http://${HA_HOST}:8765/recognize`

(`HA_HOST` = nur der Hostname/IP ohne Port, z. B. `192.168.1.100`)

## Hinweise

- Nutze das `Bash`-Tool mit `curl` für alle API-Aufrufe
- Für komplexe Antworten: `| jq` zum Parsen
- HA-Websocket-API für Echtzeit-Events (falls nötig): `ws://$HA_URL/api/websocket`
- Bei Fehlern: Status-Code 401 = Token ungültig, 404 = Entität nicht gefunden
