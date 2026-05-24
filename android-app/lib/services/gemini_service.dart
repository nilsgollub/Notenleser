import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'omr_service.dart';

/// Optical Music Recognition über die Gemini 2.0 Flash API.
/// Kostenloser Tier: 15 req/min, 1 500 req/Tag.
class GeminiService implements OmrService {
  static const _model = 'gemini-2.0-flash';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

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
- pitch in wissenschaftlicher Notation: C4 = mittleres C. Vorzeichen als # oder b
  (z. B. F#5, Bb3). Pausen als "REST".
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
        'responseMimeType': 'application/json',
      },
    });

    http.Response res;
    try {
      final uri = Uri.parse('$_baseUrl?key=$apiKey');
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

    if (res.statusCode == 400 || res.statusCode == 403) {
      throw OmrException('Gemini API-Key ungültig. Bitte in den Einstellungen prüfen.');
    }
    if (res.statusCode == 429) {
      throw OmrException(
          'Gemini-Tageslimit erreicht (1 500 kostenlose Anfragen/Tag). '
          'Morgen wieder verfügbar oder auf Claude wechseln.');
    }
    if (res.statusCode >= 500) {
      throw OmrException(
          'Server-Fehler bei Google (${res.statusCode}). Später erneut versuchen.');
    }
    if (res.statusCode != 200) {
      final detail = _extractErrorMessage(res.body);
      throw OmrException('Anfrage fehlgeschlagen (${res.statusCode}): $detail');
    }

    final jsonText = _extractText(res.body);
    final data = _parseJsonObject(jsonText);
    final song = Song.fromClaudeJson(data);

    if (song.notes.isEmpty) {
      throw OmrException(
          'Es konnten keine Noten erkannt werden. Bitte ein schärferes, '
          'gerade ausgerichtetes Foto mit gutem Kontrast versuchen.');
    }
    return song;
  }

  String _extractText(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List? ?? const [];
    if (candidates.isEmpty) throw OmrException('Gemini hat keine Antwort geliefert.');
    final parts =
        (candidates.first as Map)['content']?['parts'] as List? ?? const [];
    return parts.whereType<Map>().map((p) => p['text']?.toString() ?? '').join();
  }

  Map<String, dynamic> _parseJsonObject(String text) {
    final t = text.trim();
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw OmrException('Antwort konnte nicht als Noten gelesen werden.');
    }
    try {
      return jsonDecode(t.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      throw OmrException('Antwort der Notenerkennung war ungültig.');
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
