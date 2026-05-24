import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'omr_service.dart';

class BackendService implements OmrService {
  const BackendService({required this.baseUrl});
  final String baseUrl;

  String get _base => baseUrl.replaceAll(RegExp(r'/+$'), '');

  @override
  Future<Song> recognize({required String apiKey, required File imageFile}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/recognize'));
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 360));
    } on SocketException {
      throw OmrException(
          'Server nicht erreichbar. Läuft das OMR-Addon auf dem Raspberry Pi?');
    } catch (_) {
      throw OmrException(
          'Zeitüberschreitung. Die Notenerkennung kann auf dem Raspberry Pi 2–5 Minuten dauern.');
    }

    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 422) {
      throw OmrException(
          'Kein Notenblatt erkannt. Bitte ein deutlicheres Foto versuchen.');
    }
    if (res.statusCode >= 500) {
      final msg = _extractError(res.body);
      throw OmrException('Server-Fehler (${res.statusCode}): $msg');
    }
    if (res.statusCode != 200) {
      throw OmrException('Anfrage fehlgeschlagen (${res.statusCode}).');
    }

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final song = Song.fromClaudeJson(data);
      if (song.notes.isEmpty) {
        throw OmrException(
            'Es konnten keine Noten erkannt werden. Bitte ein schärferes, '
            'gerade ausgerichtetes Foto mit gutem Kontrast versuchen.');
      }
      return song;
    } on OmrException {
      rethrow;
    } catch (_) {
      throw OmrException('Antwort des Servers konnte nicht verarbeitet werden.');
    }
  }

  static Future<bool> testConnection(String url) async {
    try {
      final base = url.replaceAll(RegExp(r'/+$'), '');
      final res = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String _extractError(String body) {
    try {
      final d = jsonDecode(body) as Map<String, dynamic>;
      return (d['detail'] ?? body).toString();
    } catch (_) {
      return body.length > 120 ? '${body.substring(0, 120)}…' : body;
    }
  }
}
