import 'package:shared_preferences/shared_preferences.dart';

/// Speichert/lädt den Anthropic API-Key lokal auf dem Gerät.
class SettingsService {
  static const _kApiKey = 'anthropic_api_key';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_kApiKey);
    return (key == null || key.trim().isEmpty) ? null : key.trim();
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, key.trim());
  }

  Future<bool> hasApiKey() async => (await getApiKey()) != null;
}
