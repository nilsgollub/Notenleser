import 'package:shared_preferences/shared_preferences.dart';
import 'omr_service.dart';

class SettingsService {
  static const _kProvider = 'omr_provider';
  static const _kClaudeKey = 'anthropic_api_key';
  static const _kGeminiKey = 'gemini_api_key';

  Future<OmrProvider> getProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kProvider) == 'gemini'
        ? OmrProvider.gemini
        : OmrProvider.claude;
  }

  Future<void> setProvider(OmrProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvider, provider.name);
  }

  Future<String?> getClaudeApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_kClaudeKey);
    return (key == null || key.trim().isEmpty) ? null : key.trim();
  }

  Future<void> setClaudeApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClaudeKey, key.trim());
  }

  Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_kGeminiKey);
    return (key == null || key.trim().isEmpty) ? null : key.trim();
  }

  Future<void> setGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGeminiKey, key.trim());
  }

  Future<String?> getActiveApiKey() async {
    final provider = await getProvider();
    return provider == OmrProvider.gemini ? getGeminiApiKey() : getClaudeApiKey();
  }

  Future<bool> hasActiveApiKey() async => (await getActiveApiKey()) != null;

  // Abwärtskompatibilität – alter Code nutzt getApiKey()/setApiKey()
  Future<String?> getApiKey() => getClaudeApiKey();
  Future<void> setApiKey(String key) => setClaudeApiKey(key);
  Future<bool> hasApiKey() => hasActiveApiKey();
}
