import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/song.dart';
import '../services/claude_service.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../services/omr_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

enum _Stage { idle, processing, done, error }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _settings = SettingsService();

  File? _image;
  _Stage _stage = _Stage.idle;
  String _error = '';
  Song? _result;
  bool _hasKey = false;
  OmrProvider _provider = OmrProvider.gemini;

  @override
  void initState() {
    super.initState();
    _refreshSettings();
  }

  Future<void> _refreshSettings() async {
    final has = await _settings.hasActiveApiKey();
    final provider = await _settings.getProvider();
    if (mounted) setState(() {
      _hasKey = has;
      _provider = provider;
    });
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        imageQuality: 92,
      );
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _stage = _Stage.idle;
        _error = '';
      });
    } catch (e) {
      setState(() {
        _stage = _Stage.error;
        _error = 'Bild konnte nicht geladen werden: $e';
      });
    }
  }

  Future<void> _scan() async {
    final apiKey = await _settings.getActiveApiKey();
    if (apiKey == null) {
      _openSettings();
      return;
    }
    if (_image == null) return;

    setState(() {
      _stage = _Stage.processing;
      _error = '';
    });

    final OmrService service =
        _provider == OmrProvider.gemini ? GeminiService() : ClaudeService();

    try {
      final song = await service.recognize(apiKey: apiKey, imageFile: _image!);
      final saved = await DatabaseService.instance.insert(song);
      if (!mounted) return;
      setState(() {
        _result = saved;
        _stage = _Stage.done;
      });
    } on OmrException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = 'Unerwarteter Fehler: $e';
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _refreshSettings();
  }

  void _reset() => setState(() {
        _image = null;
        _stage = _Stage.idle;
        _error = '';
        _result = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noten scannen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildStage(),
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.processing:
        return _processing();
      case _Stage.done:
        return _done();
      case _Stage.error:
        return _errorView();
      case _Stage.idle:
        return _idle();
    }
  }

  Widget _idle() {
    return ListView(
      children: [
        if (!_hasKey) _keyBanner(),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: _image == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 48, color: AppColors.primary),
                        SizedBox(height: 12),
                        Text('Noch kein Foto ausgewählt',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : Image.file(_image!, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Kamera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galerie'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _image == null ? null : _scan,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Noten erkennen'),
        ),
        const SizedBox(height: 12),
        _providerIndicator(),
      ],
    );
  }

  Widget _providerIndicator() {
    final isGemini = _provider == OmrProvider.gemini;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isGemini ? Icons.auto_awesome_outlined : Icons.psychology_outlined,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          isGemini ? 'Gemini 2.0 Flash (kostenlos)' : 'Claude Opus (kostenpflichtig)',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _keyBanner() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.key_outlined, color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Kein API-Key hinterlegt. Für die Erkennung benötigt.',
                  style: TextStyle(fontSize: 13)),
            ),
            TextButton(onPressed: _openSettings, child: const Text('Einrichten')),
          ],
        ),
      );

  Widget _processing() {
    final isGemini = _provider == OmrProvider.gemini;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 20),
          const Text('Noten werden gelesen…',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            isGemini
                ? 'Gemini analysiert das Notenblatt (kann ~15 Sek. dauern).'
                : 'Claude analysiert das Notenblatt (kann ~30 Sek. dauern).',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _done() {
    final song = _result!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 56),
          const SizedBox(height: 16),
          Text(song.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${song.notes.length} Noten · ${song.keySignature} · ♩=${song.tempoBpm}',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PlayerScreen(song: song)),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Jetzt anhören'),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: _reset, child: const Text('Weiteres Lied scannen')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Zur Bibliothek'),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 56),
          const SizedBox(height: 16),
          Text(_error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _reset, child: const Text('Nochmal versuchen')),
        ],
      ),
    );
  }
}
