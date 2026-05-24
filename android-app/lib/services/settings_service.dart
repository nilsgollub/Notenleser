import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_service.dart';
import 'omr_service.dart';

class SettingsService {
  static const _kProvider   = 'omr_provider';
  static const _kClaudeKey  = 'anthropic_api_key';
  static const _kGeminiKey  = 'gemini_api_key';
  static const _kGeminiModel = 'gemini_model';
  static const _kBackendUrl = 'backend_url';

  Future<OmrProvider> getProvider() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_kProvider)) {
      case 'gemini':  return OmrProvider.gemini;
      case 'backend': return OmrProvider.backend;
      default:        return OmrProvider.claude;
    }
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

  Future<String> getGeminiModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kGeminiModel) ?? GeminiService.defaultModel;
  }

  Future<void> setGeminiModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGeminiModel, model);
  }

  Future<String?> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_kBackendUrl);
    return (url == null || url.trim().isEmpty) ? null : url.trim();
  }

  Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackendUrl, url.trim());
  }

  /// Returns the active credential: API key for cloud providers, URL for backend.
  Future<String?> getActiveApiKey() async {
    switch (await getProvider()) {
      case OmrProvider.gemini:  return getGeminiApiKey();
      case OmrProvider.claude:  return getClaudeApiKey();
      case OmrProvider.backend: return getBackendUrl();
    }
  }

  Future<bool> hasActiveApiKey() async => (await getActiveApiKey()) != null;

  // Abwärtskompatibilität
  Future<String?> getApiKey() => getClaudeApiKey();
  Future<void> setApiKey(String key) => setClaudeApiKey(key);
  Future<bool> hasApiKey() => hasActiveApiKey();
}
