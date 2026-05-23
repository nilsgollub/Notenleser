import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import '../models/note_event.dart';

/// Synthetisiert die Melodie offline zu WAV und spielt sie ab.
/// Liefert außerdem die Zeitachse für den Karaoke-Cursor.
class AudioService {
  AudioService({required this.notes, required this.baseBpm});

  final List<NoteEvent> notes;
  final int baseBpm;

  final AudioPlayer _player = AudioPlayer();
  static const int _sampleRate = 44100;

  double _tempoMultiplier = 1.0;
  List<double> _startTimes = const [];
  double _totalSeconds = 0;

  // ── Öffentliche Getter ─────────────────────────────────────────────────
  double get tempoMultiplier => _tempoMultiplier;
  double get totalSeconds => _totalSeconds;
  List<double> get startTimes => _startTimes;

  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  double get effectiveBpm => baseBpm * _tempoMultiplier;

  /// Index der bei [seconds] klingenden Note (oder -1 vor dem Start).
  int currentNoteIndex(double seconds) {
    if (_startTimes.isEmpty) return -1;
    int lo = 0, hi = _startTimes.length - 1, res = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_startTimes[mid] <= seconds) {
        res = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return res;
  }

  /// Synthetisiert die Melodie und lädt sie in den Player.
  Future<void> load() async {
    final wav = _synthesize();
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(BytesSource(wav, mimeType: 'audio/wav'));
  }

  Future<void> play() => _player.resume();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(double seconds) =>
      _player.seek(Duration(milliseconds: (seconds * 1000).round()));

  Future<void> restart() async {
    await _player.seek(Duration.zero);
    await _player.resume();
  }

  /// Ändert das Tempo (0.5–1.5) und synthetisiert neu – die Tonhöhe bleibt korrekt.
  Future<void> setTempoMultiplier(double m) async {
    _tempoMultiplier = m.clamp(0.5, 1.5);
    await _player.stop();
    final wav = _synthesize();
    await _player.setSource(BytesSource(wav, mimeType: 'audio/wav'));
  }

  Future<void> dispose() => _player.dispose();

  // ── Synthese ───────────────────────────────────────────────────────────
  Uint8List _synthesize() {
    final secPerBeat = 60.0 / effectiveBpm;

    // Zeitachse aufbauen
    final starts = <double>[];
    double t = 0;
    for (final n in notes) {
      starts.add(t);
      t += n.durationBeats * secPerBeat;
    }
    _startTimes = starts;
    _totalSeconds = t;

    final totalSamples = (_totalSeconds * _sampleRate).ceil() + _sampleRate ~/ 4;
    final buffer = Float64List(totalSamples);

    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      if (note.isRest) continue;
      final freq = note.frequency;
      if (freq <= 0) continue;

      final startSample = (starts[i] * _sampleRate).floor();
      final durSeconds = note.durationBeats * secPerBeat;
      // Kleine Lücke am Ende, damit Töne sich nicht verschmieren.
      final durSamples = (durSeconds * _sampleRate * 0.92).floor();

      final attack = math.min(0.012 * _sampleRate, durSamples * 0.15);
      final release = math.min(0.06 * _sampleRate, durSamples * 0.3);

      for (var n = 0; n < durSamples; n++) {
        final idx = startSample + n;
        if (idx >= totalSamples) break;
        final tt = n / _sampleRate;

        // ADSR-Hüllkurve (einfach: linear A / Sustain / linear R)
        double env;
        if (n < attack) {
          env = n / attack;
        } else if (n > durSamples - release) {
          env = (durSamples - n) / release;
        } else {
          env = 0.8;
        }

        // Grundton + zwei Obertöne für einen volleren Klang
        final w = 2 * math.pi * freq * tt;
        final sample = math.sin(w) +
            0.3 * math.sin(2 * w) +
            0.15 * math.sin(3 * w);

        buffer[idx] += env * sample;
      }
    }

    // Normalisieren gegen Clipping
    double peak = 0;
    for (final s in buffer) {
      final a = s.abs();
      if (a > peak) peak = a;
    }
    final gain = peak > 0 ? (0.9 / peak) : 1.0;

    final pcm = Int16List(totalSamples);
    for (var i = 0; i < totalSamples; i++) {
      final v = (buffer[i] * gain * 32767).round();
      pcm[i] = v.clamp(-32768, 32767);
    }

    return _wrapWav(pcm, _sampleRate);
  }

  /// Verpackt 16-bit-PCM (mono) in einen WAV-Container.
  Uint8List _wrapWav(Int16List pcm, int sampleRate) {
    final dataBytes = pcm.buffer.asUint8List(0, pcm.lengthInBytes);
    final byteRate = sampleRate * 2; // mono, 16-bit
    final totalLen = 44 + dataBytes.length;

    final out = Uint8List(totalLen);
    final bd = ByteData.view(out.buffer);

    out.setRange(0, 4, 'RIFF'.codeUnits);
    bd.setUint32(4, 36 + dataBytes.length, Endian.little);
    out.setRange(8, 12, 'WAVE'.codeUnits);
    out.setRange(12, 16, 'fmt '.codeUnits);
    bd.setUint32(16, 16, Endian.little); // PCM fmt chunk size
    bd.setUint16(20, 1, Endian.little); // Audioformat = PCM
    bd.setUint16(22, 1, Endian.little); // Kanäle = mono
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, 2, Endian.little); // Block-Align (mono * 16bit / 8)
    bd.setUint16(34, 16, Endian.little); // Bits pro Sample
    out.setRange(36, 40, 'data'.codeUnits);
    bd.setUint32(40, dataBytes.length, Endian.little);
    out.setRange(44, totalLen, dataBytes);

    return out;
  }
}
