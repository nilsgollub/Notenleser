import 'dart:math' as math;
import '../models/note_event.dart';
import '../models/song.dart';

/// Wandelt ABC-Notation in ein [Song]-Objekt um.
class AbcParser {
  static const _sharpsOrder = ['F', 'C', 'G', 'D', 'A', 'E', 'B'];
  static const _flatsOrder  = ['B', 'E', 'A', 'D', 'G', 'C', 'F'];

  Song parse(String abc) {
    // Strip markdown code fences
    abc = abc
        .replaceAll(RegExp(r'^```\w*\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
        .trim();

    final lines = abc.split('\n').map((l) => l.trim()).toList();

    var title = '';
    var composer = '';
    var timeSignature = '4/4';
    var tempoBpm = 100;
    var keyAbc = 'C';
    var unitBeats = 1.0; // L:1/4 → 1.0 beat per unit

    final musicLines = <String>[];
    final lyricLines = <String>[];

    for (final line in lines) {
      if (line.isEmpty || line.startsWith('%')) continue;
      if (line.startsWith('T:')) { if (title.isEmpty) title = line.substring(2).trim(); continue; }
      if (line.startsWith('C:')) { composer = line.substring(2).trim(); continue; }
      if (line.startsWith('M:')) { timeSignature = line.substring(2).trim(); continue; }
      if (line.startsWith('L:')) { unitBeats = _unitLength(line.substring(2).trim()); continue; }
      if (line.startsWith('K:')) { keyAbc = line.substring(2).trim(); continue; }
      if (line.startsWith('Q:')) {
        final m = RegExp(r'(\d+)\s*$').firstMatch(line.substring(2));
        if (m != null) tempoBpm = int.tryParse(m.group(1)!) ?? 100;
        continue;
      }
      if (line.startsWith('w:')) { lyricLines.add(line.substring(2)); continue; }
      if (RegExp(r'^[A-Za-z]:').hasMatch(line)) continue;
      musicLines.add(line);
    }

    final keyAcc = _buildKeyAcc(keyAbc);
    final notes = _parseNotes(musicLines.join(' '), unitBeats, keyAcc);
    if (lyricLines.isNotEmpty) {
      _applyLyrics(notes, lyricLines.join(' '));
    }

    return Song(
      title: title.isEmpty ? 'Unbekanntes Lied' : title,
      composer: composer.isEmpty ? null : composer,
      keySignature: _keyToGerman(keyAbc),
      timeSignature: timeSignature,
      tempoBpm: tempoBpm,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  double _unitLength(String s) {
    final p = s.split('/');
    if (p.length == 2) {
      final n = double.tryParse(p[0].trim()) ?? 1;
      final d = double.tryParse(p[1].trim()) ?? 4;
      return (n / d) * 4; // convert to beats (whole note = 4 beats)
    }
    return 1.0;
  }

  Map<String, int> _buildKeyAcc(String keyAbc) {
    final m = RegExp(r'^([A-Ga-g][b#]?)(.*)').firstMatch(keyAbc.trim());
    if (m == null) return {};
    var root = m.group(1)!;
    root = root[0].toUpperCase() + root.substring(1);
    final mode = m.group(2)!.trim().toLowerCase();
    final isMinor = mode.startsWith('m') && !mode.startsWith('mix');

    if (isMinor) {
      const rel = {
        'A': 'C', 'E': 'G', 'B': 'D', 'F#': 'A', 'C#': 'E', 'G#': 'B',
        'D': 'F', 'G': 'Bb', 'C': 'Eb', 'F': 'Ab',
      };
      root = rel[root] ?? root;
    }

    const sMap = {'C': 0, 'G': 1, 'D': 2, 'A': 3, 'E': 4, 'B': 5, 'F#': 6, 'C#': 7};
    const fMap = {'F': 1, 'Bb': 2, 'Eb': 3, 'Ab': 4, 'Db': 5, 'Gb': 6, 'Cb': 7};

    final acc = <String, int>{};
    if (sMap.containsKey(root)) {
      for (var i = 0; i < sMap[root]!; i++) acc[_sharpsOrder[i]] = 1;
    } else if (fMap.containsKey(root)) {
      for (var i = 0; i < fMap[root]!; i++) acc[_flatsOrder[i]] = -1;
    }
    return acc;
  }

  List<NoteEvent> _parseNotes(
      String body, double unitBeats, Map<String, int> keyAcc) {
    final notes = <NoteEvent>[];
    var measure = 1;
    final barAcc = <String, int>{}; // per-measure accidental carry

    // Remove grace notes and inline chord content (keep first note only via regex order)
    final cleaned = body
        .replaceAll(RegExp(r'\{[^}]*\}'), '') // grace notes {cde}
        .replaceAll(RegExp(r'!"[^"]*"'), ''); // inline annotations

    final re = RegExp(
      r"([_^=]{0,2})([A-Ga-g])([,']*)(\d*)(/+\d*)?" // note
      r'|(z|Z)(\d*)(/+\d*)?' // rest
      r'|([:|]*\|{1,2}[\]:]?|:\|[\]:]?)' // bar line
    );

    for (final t in re.allMatches(cleaned)) {
      if (t.group(2) != null) {
        // Note
        final accStr = t.group(1)!;
        final letter = t.group(2)!;
        final octMod = t.group(3)!;
        final numStr = t.group(4)!;
        final divStr = t.group(5) ?? '';
        final dur = _durVal(numStr, divStr) * unitBeats;
        final up = letter.toUpperCase();

        int? acc;
        if (accStr.contains('^'))      acc = accStr.length > 1 ? 2 : 1;
        else if (accStr.contains('_')) acc = accStr.length > 1 ? -2 : -1;
        else if (accStr == '=')        acc = 0;
        if (acc != null) barAcc[up] = acc;

        final resolvedAcc = barAcc[up] ?? keyAcc[up] ?? 0;
        final oct = _noteOctave(letter, octMod);

        notes.add(NoteEvent(
          pitch: _pitchStr(up, resolvedAcc, oct),
          durationBeats: dur,
          measure: measure,
        ));
      } else if (t.group(6) != null) {
        // Rest
        final dur = _durVal(t.group(7) ?? '', t.group(8) ?? '') * unitBeats;
        notes.add(NoteEvent(pitch: 'REST', durationBeats: dur, measure: measure));
      } else if (t.group(9) != null) {
        // Bar line → new measure, reset accidentals
        measure++;
        barAcc.clear();
      }
    }

    return notes;
  }

  double _durVal(String num, String div) {
    final n = num.isEmpty ? 1.0 : (double.tryParse(num) ?? 1.0);
    if (div.isEmpty) return n;
    final slashes = div.replaceAll(RegExp(r'[^/]'), '').length;
    final dStr = div.replaceAll('/', '');
    final d = dStr.isEmpty
        ? math.pow(2, slashes).toDouble()
        : (double.tryParse(dStr) ?? 1.0);
    return n / d;
  }

  int _noteOctave(String letter, String mods) {
    var o = (letter.codeUnitAt(0) >= 97) ? 5 : 4; // lowercase → octave 5
    for (final c in mods.split('')) {
      if (c == ',') o--;
      if (c == "'") o++;
    }
    return o;
  }

  String _pitchStr(String letter, int acc, int oct) {
    const s = {1: '#', -1: 'b', 2: '##', -2: 'bb', 0: ''};
    return '$letter${s[acc] ?? ''}$oct';
  }

  /// Applies w: lyrics to the note list.
  /// Each space-separated token maps to one non-rest note.
  /// Tokens ending with '-' keep the hyphen (word-break indicator).
  /// '_' = extend previous syllable (skip note), '*' = skip note.
  void _applyLyrics(List<NoteEvent> notes, String rawLyrics) {
    final syllables = rawLyrics.trim().split(RegExp(r'[ \t]+'));
    var si = 0;
    for (int i = 0; i < notes.length && si < syllables.length; i++) {
      if (notes[i].isRest) continue;
      final syl = syllables[si++];
      if (syl == '_') { si--; continue; }
      if (syl == '*') continue;
      final clean = syl.trim();
      if (clean.isEmpty) continue;
      notes[i] = NoteEvent(
        pitch: notes[i].pitch,
        durationBeats: notes[i].durationBeats,
        measure: notes[i].measure,
        lyric: clean,
      );
    }
  }

  String _keyToGerman(String keyAbc) {
    final m = RegExp(r'^([A-Ga-g][b#]?)(.*)').firstMatch(keyAbc.trim());
    if (m == null) return keyAbc;
    var tonic = m.group(1)!;
    tonic = tonic[0].toUpperCase() + tonic.substring(1);
    final mode = m.group(2)!.trim().toLowerCase();
    final isMinor = mode.startsWith('m') && !mode.startsWith('mix');

    const names = {
      'C': 'C',  'D': 'D',   'E': 'E',   'F': 'F',   'G': 'G',  'A': 'A', 'B': 'H',
      'Bb': 'B', 'Eb': 'Es', 'Ab': 'As', 'Db': 'Des','Gb': 'Ges','Cb': 'Ces',
      'F#': 'Fis','C#': 'Cis','G#': 'Gis','D#': 'Dis','A#': 'Ais',
    };
    final n = names[tonic] ?? tonic;
    return isMinor ? '${n.toLowerCase()}-Moll' : '$n-Dur';
  }
}
