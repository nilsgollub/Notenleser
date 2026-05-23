import 'dart:convert';
import 'note_event.dart';

/// Ein erfasstes Lied inkl. Metadaten und Noten.
class Song {
  final int? id;
  final String title;
  final String? composer;
  final String keySignature; // z. B. "C-Dur"
  final String timeSignature; // z. B. "4/4"
  final int tempoBpm;
  final List<NoteEvent> notes;
  final DateTime createdAt;

  const Song({
    this.id,
    required this.title,
    this.composer,
    required this.keySignature,
    required this.timeSignature,
    required this.tempoBpm,
    required this.notes,
    required this.createdAt,
  });

  Song copyWith({int? id}) => Song(
        id: id ?? this.id,
        title: title,
        composer: composer,
        keySignature: keySignature,
        timeSignature: timeSignature,
        tempoBpm: tempoBpm,
        notes: notes,
        createdAt: createdAt,
      );

  /// Antwort der Claude Vision API → Song.
  factory Song.fromClaudeJson(Map<String, dynamic> json) {
    final rawNotes = (json['notes'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(NoteEvent.fromJson)
        .toList();
    final composer = (json['composer'] ?? '').toString().trim();
    return Song(
      title: (json['title'] ?? 'Unbekanntes Lied').toString().trim().isEmpty
          ? 'Unbekanntes Lied'
          : json['title'].toString().trim(),
      composer: composer.isEmpty ? null : composer,
      keySignature: (json['key'] ?? '').toString(),
      timeSignature: (json['time_signature'] ?? '4/4').toString(),
      tempoBpm: (json['tempo_bpm'] as num?)?.toInt() ?? 100,
      notes: rawNotes,
      createdAt: DateTime.now(),
    );
  }

  // ── SQLite-Serialisierung ────────────────────────────────────────────────
  Map<String, dynamic> toDbMap() => {
        if (id != null) 'id': id,
        'title': title,
        'composer': composer,
        'key_signature': keySignature,
        'time_signature': timeSignature,
        'tempo_bpm': tempoBpm,
        'notes_json': jsonEncode(notes.map((n) => n.toJson()).toList()),
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Song.fromDbMap(Map<String, dynamic> map) {
    final notesList = (jsonDecode(map['notes_json'] as String) as List)
        .whereType<Map<String, dynamic>>()
        .map(NoteEvent.fromJson)
        .toList();
    return Song(
      id: map['id'] as int?,
      title: map['title'] as String,
      composer: map['composer'] as String?,
      keySignature: map['key_signature'] as String? ?? '',
      timeSignature: map['time_signature'] as String? ?? '4/4',
      tempoBpm: map['tempo_bpm'] as int? ?? 100,
      notes: notesList,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int? ?? 0),
    );
  }
}
