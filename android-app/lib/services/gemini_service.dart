import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'abc_parser.dart';
import 'omr_service.dart';

class GeminiService implements OmrService {
  static const defaultModel = 'gemini-2.5-flash';
  static const _apiBase = 'https://generativelanguage.googleapis.com/v1beta';

  const GeminiService({this.model = defaultModel});
  final String model;

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

  @override
  Future<Song> recognize({required String apiKey, required File imageFile}) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType =
        imageFile.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'inline_data': {'mime_type': mimeType, 'data': base64Image}},
            {'text': _prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
      },
    });

    http.Response res;
    try {
      final uri = Uri.parse('$_apiBase/models/$model:generateContent?key=$apiKey');
      res = await http
          .post(uri, headers: {'content-type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 120));
    } on SocketException {
      throw OmrException(
          'Keine Internetverbindung. Die Notenerkennung braucht Online-Zugang.');
    } catch (_) {
      throw OmrException(
          'Zeitüberschreitung oder Netzwerkfehler. Bitte erneut versuchen.');
    }

    if (res.statusCode == 403) {
      throw OmrException('Gemini API-Key ungültig. Bitte in den Einstellungen prüfen.');
    }
    if (res.statusCode == 404) {
      throw OmrException('Modell "$model" nicht gefunden. Bitte in den Einstellungen ein anderes Modell wählen.');
    }
    if (res.statusCode == 429) {
      throw OmrException(
          'Rate-Limit erreicht. Kurz warten und erneut versuchen, oder auf Claude wechseln.');
    }
    if (res.statusCode >= 500) {
      throw OmrException(
          'Server-Fehler bei Google (${res.statusCode}). Später erneut versuchen.');
    }
    if (res.statusCode != 200) {
      final detail = _extractErrorMessage(res.body);
      throw OmrException('Anfrage fehlgeschlagen (${res.statusCode}): $detail');
    }

    final abcText = _extractText(res.body);
    Song song;
    try {
      song = AbcParser().parse(abcText);
    } catch (_) {
      throw OmrException('Antwort der Notenerkennung konnte nicht gelesen werden.');
    }

    if (song.notes.isEmpty) {
      throw OmrException(
          'Es konnten keine Noten erkannt werden. Bitte ein schärferes, '
          'gerade ausgerichtetes Foto mit gutem Kontrast versuchen.');
    }
    return song;
  }

  /// Lädt die verfügbaren Gemini-Modelle die generateContent unterstützen.
  static Future<List<String>> fetchModels(String apiKey) async {
    try {
      final uri = Uri.parse('$_apiBase/models?key=$apiKey&pageSize=100');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final models = (data['models'] as List? ?? []).cast<Map<String, dynamic>>();
      return models
          .where((m) =>
              ((m['supportedGenerationMethods'] as List?) ?? [])
                  .contains('generateContent'))
          .map((m) => (m['name'] as String).replaceFirst('models/', ''))
          .where((name) => name.contains('gemini'))
          .toList()
        ..sort();
    } catch (_) {
      return [];
    }
  }

  String _extractText(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List? ?? const [];
    if (candidates.isEmpty) throw OmrException('Gemini hat keine Antwort geliefert.');
    final parts =
        (candidates.first as Map)['content']?['parts'] as List? ?? const [];
    return parts.whereType<Map>().map((p) => p['text']?.toString() ?? '').join();
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
