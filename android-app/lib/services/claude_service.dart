import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'abc_parser.dart';
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

Gib AUSSCHLIESSLICH ABC-Notation zurück, ohne erklärenden Text davor oder danach.

Beispiel-Ausgabe (Hänschen Klein, G-Dur, 3/4-Takt):
T:Hänschen klein
C:Volksweise
M:3/4
Q:1/4=120
L:1/4
K:G
G A B | c2 d | e3 | d3 |
w:Hänsch- en klein ging al- lein
c B A | G2 A | B3 | G3 |
w:in die wei- te Welt hin- ein

Format-Regeln:
- L:1/4 immer verwenden (Einheit = Viertelnote = 1 Schlag)
- Tonhöhe: Großbuchstabe C–B = C4–B4 (mittleres C = C), Kleinbuchstabe c–b = C5–B5;
  Komma senkt Oktave (C, = C3, C,, = C2), Apostroph erhöht (c' = C6)
- Dauer: C = 1, C2 = 2, C4 = 4, C/ = 0,5, C3/2 = 1,5 (Schläge bei L:1/4)
- Pausen: z = Viertelpause, z2 = Halbe, z4 = ganze Pause, z/ = Achtelpause
  JEDE rhythmische Pause muss als z notiert werden – keine Pause auslassen!
- Vorzeichen: ^C = Cis, _B = Bb, =C = C-natural (hebt Vorzeichen auf)
  Vorzeichen gelten bis zum nächsten Taktstrich
- Taktstriche: | zwischen Takten
- Liedtext (w:): Jede Silbe als eigenes Wort, Bindestrich am Ende wenn Wort weitergeht
  (z. B. "Hänsch- en klein"), w:-Zeile direkt nach der zugehörigen Notenzeile
  Pausen bekommen keine Lyrik (in der w:-Zeile mit * überspringen)
- Keine Akkorde, keine Mehrstimmigkeit – nur die Melodiestimme
- Kein lesbares Notenblatt: nur leere Header ausgeben, keine Noten
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

    final abcText = _extractText(res.body);
    Song song;
    try {
      song = AbcParser().parse(abcText);
    } catch (_) {
      throw ClaudeException('Antwort der Notenerkennung konnte nicht gelesen werden.');
    }

    if (song.notes.isEmpty) {
      throw ClaudeException(
          'Es konnten keine Noten erkannt werden. Bitte ein schärferes, '
          'gerade ausgerichtetes Foto mit gutem Kontrast versuchen.');
    }
    return song;
  }

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

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return (decoded['error']?['message'] ?? body).toString();
    } catch (_) {
      return body;
    }
  }
}
