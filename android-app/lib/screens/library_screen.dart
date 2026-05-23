import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/database_service.dart';
import '../theme.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final songs =
        await DatabaseService.instance.getAll(query: _searchController.text.trim());
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _loading = false;
    });
  }

  Future<void> _openScan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    _load(); // nach Rückkehr aktualisieren
  }

  Future<void> _confirmDelete(Song song) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lied löschen?'),
        content: Text('„${song.title}" wird dauerhaft entfernt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true && song.id != null) {
      await DatabaseService.instance.delete(song.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notenleser'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScan,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.photo_camera_outlined, color: Colors.white),
        label: const Text('Scannen', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _load(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                hintText: 'Lied suchen…',
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _songs.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: _songs.length,
                          itemBuilder: (_, i) => SongTile(
                            song: _songs[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => PlayerScreen(song: _songs[i])),
                            ),
                            onDelete: () => _confirmDelete(_songs[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'Noch keine Lieder erfasst'
                  : 'Keine Treffer',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (_searchController.text.isEmpty)
              FilledButton.icon(
                onPressed: _openScan,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Erstes Lied scannen'),
              ),
          ],
        ),
      ),
    );
  }
}
