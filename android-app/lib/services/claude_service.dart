import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'omr_service.dart';

class ClaudeException extends OmrException {
  ClaudeException(super.message);
}

class ClaudeService implements OmrService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-opus-4-7';
  static const _anthropicVersion = '2023-06-01';

  static const _prompt = '''
Du bist ein Experte für Notenlesen (Optical Music Recognition).
Analysiere das beigefügte Foto eines Notenblatts und extrahiere die Melodie
(die Hauptstimme – bei mehreren Systemen die oberste Melodielinie).

Gib AUSSCHLIESSLICH ein JSON-Objekt zurück, ohne erklärenden Text davor oder
danach, in genau dieser Struktur:

{
  "title": "Titel des Stücks (oder leerer String wenn unbekannt)",
  "composer": "Komponist (oder leerer String wenn unbekannt)",
  "key": "Tonart auf Deutsch, z. B. C-Dur oder a-Moll",
  "time_signature": "Taktart, z. B. 4/4 oder 3/4",
  "tempo_bpm": 100,
  "notes": [
    { "pitch": "C4", "duration_beats": 1.0, "measure": 1, "lyric": "Hän-" }
  ]
}

Regeln:
- pitch: wissenschaftliche Notation, C4 = mittleres C. Vorzeichen als # oder b
  (z. B. F#5, Bb3). WICHTIG: Pausen/Stille als "REST" angeben.
- WICHTIG PAUSEN: Füge für JEDE rhythmische Pause (Viertel-, Halb-, ganze Pause
  usw.) eine eigene Note mit pitch="REST" und der korrekten duration_beats ein.
  Pausen zwischen Tönen dürfen nicht weggelassen werden.
- duration_beats: Dauer in Schlägen. Ganze Note = 4.0, Halbe = 2.0,
  Viertel = 1.0, Achtel = 0.5, Sechzehntel = 0.25. Punktierungen entsprechend
  (punktierte Viertel = 1.5).
- measure: 1-basierte Taktnummer.
- lyric: Die unter der Note gedruckte Silbe oder das Wort, EXAKT wie im Notenblatt
  (inklusive Trennstriche, z. B. "Hän-", "sel", "und"). Lasse das Feld weg (oder
  leerer String) wenn keine Lyrik für diese Note vorhanden ist. Pausen haben nie
  eine Lyrik. Hat das Stück generell keinen Text, lasse lyric bei allen Noten weg.
- Liste die Noten in der Reihenfolge auf, in der sie gespielt werden.
- tempo_bpm: falls keine Tempoangabe gedruckt ist, schätze ein passendes Tempo
  für die Stilrichtung (Kinderlieder meist 90–120).
- Wenn das Bild kein lesbares Notenblatt zeigt, gib "notes": [] zurück.
''';

  /// Liest die Noten aus einem Bild und liefert ein [Song]-Objekt.
  Future<Song> recognize({
    required String apiKey,
    required File imageFile,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mediaType =
        imageFile.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 16000,
      // Adaptive Thinking hilft beim sorgfältigen Ablesen der Noten.
      'thinking': {'type': 'adaptive'},
      'output_config': {'effort': 'high'},
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Image,
              },
            },
            {'type': 'text', 'text': _prompt},
          ],
        },
      ],
    });

    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': _anthropicVersion,
              'content-type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 180));
    } on SocketException {
      throw ClaudeException(
          'Keine Internetverbindung. Die Notenerkennung braucht Online-Zugang.');
    } catch (_) {
      throw ClaudeException(
          'Zeitüberschreitung oder Netzwerkfehler. Bitte erneut versuchen.');
    }

    if (res.statusCode == 401) {
      throw ClaudeException('API-Key ungültig. Bitte in den Einstellungen prüfen.');
    }
    if (res.statusCode == 429) {
      throw ClaudeException('Zu viele Anfragen (Rate Limit). Kurz warten und erneut versuchen.');
    }
    if (res.statusCode >= 500) {
      throw ClaudeException('Server-Fehler bei Anthropic (${res.statusCode}). Später erneut versuchen.');
    }
    if (res.statusCode != 200) {
      final detail = _extractErrorMessage(res.body);
      throw ClaudeException('Anfrage fehlgeschlagen (${res.statusCode}): $detail');
    }

    final jsonText = _extractText(res.body);
    final data = _parseJsonObject(jsonText);
    final song = Song.fromClaudeJson(data);

    if (song.notes.isEmpty) {
      throw ClaudeException(
          'Es konnten keine Noten erkannt werden. Bitte ein schärferes, '
          'gerade ausgerichtetes Foto mit gutem Kontrast versuchen.');
    }
    return song;
  }

  /// Extrahiert den zusammengesetzten Text aller text-Blöcke der Antwort.
  String _extractText(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final content = decoded['content'] as List? ?? const [];
    final buffer = StringBuffer();
    for (final block in content) {
      if (block is Map && block['type'] == 'text') {
        buffer.write(block['text'] ?? '');
      }
    }
    return buffer.toString();
  }

  /// Extrahiert das erste JSON-Objekt aus einem (evtl. mit ```json umrahmten) Text.
  Map<String, dynamic> _parseJsonObject(String text) {
    var t = text.trim();
    // Code-Fences entfernen
    t = t.replaceAll(RegExp(r'^```(?:json)?', multiLine: false), '').trim();
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw ClaudeException('Antwort konnte nicht als Noten gelesen werden.');
    }
    try {
      return jsonDecode(t.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      throw ClaudeException('Antwort der Notenerkennung war ungültig.');
    }
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return (decoded['error']?['message'] ?? body).toString();
    } catch (_) {
      return body;
    }
  }
}
