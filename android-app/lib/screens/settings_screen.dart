import 'package:flutter/material.dart';
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
  final _claudeController = TextEditingController();
  final _geminiController = TextEditingController();

  OmrProvider _provider = OmrProvider.claude;
  bool _obscureClaude = true;
  bool _obscureGemini = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = await _settings.getProvider();
    final claudeKey = await _settings.getClaudeApiKey();
    final geminiKey = await _settings.getGeminiApiKey();
    setState(() {
      _provider = provider;
      _claudeController.text = claudeKey ?? '';
      _geminiController.text = geminiKey ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _claudeController.dispose();
    _geminiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _settings.setProvider(_provider);
    await _settings.setClaudeApiKey(_claudeController.text);
    await _settings.setGeminiApiKey(_geminiController.text);
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
                const Text('KI-Anbieter',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 8),
                const Text(
                  'Wähle, welche KI deine Notenblätter erkennen soll.',
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
                  ],
                  selected: {_provider},
                  onSelectionChanged: (s) => setState(() => _provider = s.first),
                ),
                const SizedBox(height: 4),
                _providerBadge(),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                if (_provider == OmrProvider.gemini) ..._geminiFields(),
                if (_provider == OmrProvider.claude) ..._claudeFields(),
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
    if (_provider == OmrProvider.gemini) {
      return const _InfoChip(
        icon: Icons.money_off_outlined,
        text: 'Kostenlos · 1 500 Scans/Tag · Google-Konto nötig',
        color: AppColors.success,
      );
    }
    return const _InfoChip(
      icon: Icons.euro_outlined,
      text: 'Ca. 2–5 Ct. pro Scan · Höchste Erkennungsqualität',
      color: AppColors.accent,
    );
  }

  List<Widget> _geminiFields() => [
        const Text('Gemini API-Key',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'Kostenloser Tier: 15 Anfragen/min, 1 500/Tag – für die meisten Nutzer ausreichend. '
          'Den Key erhältst du unter aistudio.google.com → API-Key erstellen.',
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
      ];

  List<Widget> _claudeFields() => [
        const Text('Claude API-Key',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        const Text(
          'Die Notenerkennung nutzt Claude Opus (claude-opus-4-7, High-Res-Vision). '
          'Den Key bekommst du unter console.anthropic.com. '
          'Er wird nur lokal gespeichert und ausschließlich an api.anthropic.com gesendet.',
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
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}
