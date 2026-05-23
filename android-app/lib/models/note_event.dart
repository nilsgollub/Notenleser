import 'dart:math' as math;

/// Eine einzelne Note (oder Pause) der Melodie.
///
/// [pitch] ist wissenschaftliche Notation, z. B. "C4", "F#5", "Bb3"
/// oder "REST" für eine Pause.
/// [durationBeats] ist die Dauer in Schlägen (1.0 = Viertel, 0.5 = Achtel, 2.0 = Halbe).
/// [measure] ist die 1-basierte Taktnummer.
class NoteEvent {
  final String pitch;
  final double durationBeats;
  final int measure;

  const NoteEvent({
    required this.pitch,
    required this.durationBeats,
    required this.measure,
  });

  bool get isRest => pitch.toUpperCase() == 'REST';

  factory NoteEvent.fromJson(Map<String, dynamic> json) {
    return NoteEvent(
      pitch: (json['pitch'] ?? 'REST').toString(),
      durationBeats: (json['duration_beats'] as num?)?.toDouble() ?? 1.0,
      measure: (json['measure'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'pitch': pitch,
        'duration_beats': durationBeats,
        'measure': measure,
      };

  /// MIDI-Notennummer (A4 = 69). Pausen liefern -1.
  int get midiNote {
    if (isRest) return -1;
    final m = RegExp(r'^([A-Ga-g])([#b]?)(-?\d+)$').firstMatch(pitch.trim());
    if (m == null) return 60; // Fallback: mittleres C
    const base = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final letter = m.group(1)!.toUpperCase();
    final accidental = m.group(2)!;
    final octave = int.parse(m.group(3)!);
    var semis = base[letter]!;
    if (accidental == '#') semis += 1;
    if (accidental == 'b') semis -= 1;
    return (octave + 1) * 12 + semis;
  }

  /// Frequenz in Hz. Pausen liefern 0.
  double get frequency {
    if (isRest) return 0.0;
    return 440.0 * math.pow(2, (midiNote - 69) / 12.0);
  }
}
