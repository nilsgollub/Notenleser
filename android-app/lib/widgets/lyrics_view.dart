import 'package:flutter/material.dart';
import '../models/note_event.dart';
import '../theme.dart';

/// Eintrag in der Lyrics-Liste: der angezeigte Text und der zugehörige Noten-Index.
class _LyricToken {
  final String text;
  final int noteIndex;
  const _LyricToken(this.text, this.noteIndex);
}

/// Karaoke-Textanzeige: Alle Silben fließen als Text, die aktuelle leuchtet gold.
class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.notes,
    required this.currentIndex,
    required this.karaokeOn,
  });

  final List<NoteEvent> notes;
  final int currentIndex;
  final bool karaokeOn;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  late final List<_LyricToken> _tokens;
  final _scroll = ScrollController();
  final List<GlobalKey> _keys = [];

  @override
  void initState() {
    super.initState();
    _tokens = _buildTokens(widget.notes);
    _keys.addAll(List.generate(_tokens.length, (_) => GlobalKey()));
  }

  static List<_LyricToken> _buildTokens(List<NoteEvent> notes) {
    final out = <_LyricToken>[];
    for (var i = 0; i < notes.length; i++) {
      final l = notes[i].lyric;
      if (l != null && l.isNotEmpty) {
        out.add(_LyricToken(l, i));
      }
    }
    return out;
  }

  int get _activeTokenIndex {
    if (widget.currentIndex < 0) return -1;
    int best = -1;
    for (var i = 0; i < _tokens.length; i++) {
      if (_tokens[i].noteIndex <= widget.currentIndex) best = i;
    }
    return best;
  }

  @override
  void didUpdateWidget(LyricsView old) {
    super.didUpdateWidget(old);
    if (widget.karaokeOn && widget.currentIndex != old.currentIndex) {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    final idx = _activeTokenIndex;
    if (idx < 0 || idx >= _keys.length) return;
    final key = _keys[idx];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null || !_scroll.hasClients) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.4,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tokens.isEmpty) {
      return const Center(
        child: Text(
          'Kein Liedtext auf dem Notenblatt gefunden.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      );
    }

    final activeIdx = _activeTokenIndex;

    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Wrap(
        spacing: 0,
        runSpacing: 20,
        children: List.generate(_tokens.length, (i) {
          final token = _tokens[i];
          final isActive = i == activeIdx;
          final isPast = i < activeIdx;

          // Leerzeichen nach Silbe einfügen, wenn kein Trennstrich am Ende
          final needsSpace =
              !token.text.endsWith('-') && i + 1 < _tokens.length;

          return KeyedSubtree(
            key: _keys[i],
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: token.text,
                    style: TextStyle(
                      fontSize: isActive ? 26 : 22,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
                      color: isActive
                          ? AppColors.accent
                          : isPast
                              ? AppColors.textMuted.withOpacity(0.5)
                              : AppColors.text,
                      shadows: isActive
                          ? [
                              Shadow(
                                color: AppColors.accent.withOpacity(0.6),
                                blurRadius: 12,
                              )
                            ]
                          : null,
                      height: 1.4,
                    ),
                  ),
                  if (needsSpace)
                    const TextSpan(
                      text: ' ',
                      style: TextStyle(fontSize: 22),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
