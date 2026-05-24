import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../services/gemini_service.dart';
import '../services/omr_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _claudeController   = TextEditingController();
  final _geminiController   = TextEditingController();
  final _backendController  = TextEditingController();

  OmrProvider _provider = OmrProvider.claude;
  String _geminiModel = GeminiService.defaultModel;
  List<String> _availableModels = [];
  bool _loadingModels = false;
  bool _testingBackend = false;

  bool _obscureClaude = true;
  bool _obscureGemini = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider    = await _settings.getProvider();
    final claudeKey   = await _settings.getClaudeApiKey();
    final geminiKey   = await _settings.getGeminiApiKey();
    final geminiModel = await _settings.getGeminiModel();
    final backendUrl  = await _settings.getBackendUrl();
    setState(() {
      _provider = provider;
      _claudeController.text  = claudeKey  ?? '';
      _geminiController.text  = geminiKey  ?? '';
      _backendController.text = backendUrl ?? '';
      _geminiModel = geminiModel;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _claudeController.dispose();
    _geminiController.dispose();
    _backendController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    final key = _geminiController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst den Gemini API-Key eingeben.')),
      );
      return;
    }
    setState(() => _loadingModels = true);
    final models = await GeminiService.fetchModels(key);
    setState(() {
      _loadingModels = false;
      _availableModels = models;
      if (models.isNotEmpty && !models.contains(_geminiModel)) {
        _geminiModel = models.first;
      }
    });
    if (models.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Keine Modelle gefunden – Key prüfen oder Netzwerk.')),
      );
    }
  }

  Future<void> _testBackend() async {
    final url = _backendController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst die Server-URL eingeben.')),
      );
      return;
    }
    setState(() => _testingBackend = true);
    final ok = await BackendService.testConnection(url);
    if (!mounted) return;
    setState(() => _testingBackend = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Verbindung erfolgreich!' : 'Server nicht erreichbar.'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _save() async {
    await _settings.setProvider(_provider);
    await _settings.setClaudeApiKey(_claudeController.text);
    await _settings.setGeminiApiKey(_geminiController.text);
    await _settings.setGeminiModel(_geminiModel);
    await _settings.setBackendUrl(_backendController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Einstellungen gespeichert')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Erkennungs-Methode',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 8),
                const Text(
                  'Wähle, wie deine Notenblätter erkannt werden sollen.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SegmentedButton<OmrProvider>(
                  segments: const [
                    ButtonSegment(
                      value: OmrProvider.gemini,
                      label: Text('Gemini'),
                      icon: Icon(Icons.auto_awesome_outlined),
                    ),
                    ButtonSegment(
                      value: OmrProvider.claude,
                      label: Text('Claude'),
                      icon: Icon(Icons.psychology_outlined),
                    ),
                    ButtonSegment(
                      value: OmrProvider.backend,
                      label: Text('Server'),
                      icon: Icon(Icons.dns_outlined),
                    ),
                  ],
                  selected: {_provider},
                  onSelectionChanged: (s) => setState(() => _provider = s.first),
                ),
                const SizedBox(height: 8),
                _providerBadge(),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                if (_provider == OmrProvider.gemini)  ..._geminiFields(),
                if (_provider == OmrProvider.claude)  ..._claudeFields(),
                if (_provider == OmrProvider.backend) ..._backendFields(),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Speichern'),
                ),
              ],
            ),
    );
  }

  Widget _providerBadge() {
    switch (_provider) {
      case OmrProvider.gemini:
        return const _InfoChip(
          icon: Icons.money_off_outlined,
          text: 'Kostenlos · Kontingent je nach Modell · Google-Konto nötig',
          color: AppColors.success,
        );
      case OmrProvider.claude:
        return const _InfoChip(
          icon: Icons.euro_outlined,
          text: 'Ca. 2–5 Ct. pro Scan · Höchste Cloud-Erkennungsqualität',
          color: AppColors.accent,
        );
      case OmrProvider.backend:
        return const _InfoChip(
          icon: Icons.wifi_off_outlined,
          text: 'Lokal & offline · Zuverlässige Notenerkennung auf eigenem Server',
          color: AppColors.primary,
        );
    }
  }

  List<Widget> _geminiFields() => [
        const Text('Gemini API-Key',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'Key erstellen unter: aistudio.google.com → API-Key erstellen.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _geminiController,
          obscureText: _obscureGemini,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: 'AIza...',
            suffixIcon: IconButton(
              icon: Icon(_obscureGemini ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureGemini = !_obscureGemini),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Modell',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'Aktuell verfügbare Modelle vom Account laden, dann auswählen.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _availableModels.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.input,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _geminiModel,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _availableModels.contains(_geminiModel)
                          ? _geminiModel
                          : _availableModels.first,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.input,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      dropdownColor: AppColors.card,
                      items: _availableModels
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _geminiModel = v ?? _geminiModel),
                    ),
            ),
            const SizedBox(width: 10),
            _loadingModels
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : IconButton.filled(
                    onPressed: _fetchModels,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Modelle laden',
                  ),
          ],
        ),
      ];

  List<Widget> _claudeFields() => [
        const Text('Claude API-Key',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'Nutzt Claude Opus (claude-opus-4-7) mit High-Res-Vision.\n'
          'Key unter: console.anthropic.com. Nur lokal gespeichert.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _claudeController,
          obscureText: _obscureClaude,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: 'sk-ant-...',
            suffixIcon: IconButton(
              icon: Icon(_obscureClaude ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureClaude = !_obscureClaude),
            ),
          ),
        ),
      ];

  List<Widget> _backendFields() => [
        const Text('Server-URL',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'URL des Notenleser-OMR-Addons auf dem Raspberry Pi.\n'
          'Standardport: 8765.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _backendController,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'http://homeassistant.local:8765',
            prefixIcon: Icon(Icons.dns_outlined),
          ),
        ),
        const SizedBox(height: 12),
        _testingBackend
            ? const Center(
                child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5)))
            : OutlinedButton.icon(
                onPressed: _testBackend,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Verbindung testen'),
              ),
        const SizedBox(height: 16),
        const _InfoChip(
          icon: Icons.info_outline,
          text: 'Das OMR-Addon muss auf dem Raspberry Pi installiert und aktiv sein. '
              'Erster Start lädt Modelle (~500 MB, einmalig).',
          color: AppColors.textSecondary,
        ),
      ];
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }
}
