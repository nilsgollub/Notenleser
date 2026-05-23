import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/song.dart';
import '../services/audio_service.dart';
import '../theme.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/piano_roll.dart';
import '../widgets/player_controls.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.song});
  final Song song;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AudioService _audio;
  late final Ticker _ticker;

  final List<StreamSubscription> _subs = [];

  bool _ready = false;
  bool _isPlaying = false;
  bool _karaoke = true;
  double _displaySeconds = 0;

  // Glatte Position zwischen Player-Events interpolieren
  double _anchorSeconds = 0;
  final Stopwatch _sw = Stopwatch();

  @override
  void initState() {
    super.initState();
    _audio = AudioService(notes: widget.song.notes, baseBpm: widget.song.tempoBpm);

    _subs.add(_audio.onPositionChanged.listen((d) {
      _anchorSeconds = d.inMilliseconds / 1000.0;
      _sw
        ..reset()
        ..stop();
      if (_isPlaying) _sw.start();
    }));

    _subs.add(_audio.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (playing == _isPlaying) return;
      if (playing) {
        _sw.start();
      } else {
        _anchorSeconds += _sw.elapsedMilliseconds / 1000.0;
        _sw
          ..stop()
          ..reset();
      }
      setState(() => _isPlaying = playing);
    }));

    _subs.add(_audio.onPlayerComplete.listen((_) {
      _sw
        ..stop()
        ..reset();
      setState(() {
        _isPlaying = false;
        _anchorSeconds = _audio.totalSeconds;
        _displaySeconds = _audio.totalSeconds;
      });
    }));

    _ticker = createTicker(_onTick)..start();

    _audio.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _onTick(Duration _) {
    final pos = (_anchorSeconds + (_isPlaying ? _sw.elapsedMilliseconds / 1000.0 : 0))
        .clamp(0.0, _audio.totalSeconds <= 0 ? 0.0 : _audio.totalSeconds);
    if ((pos - _displaySeconds).abs() > 0.001) {
      setState(() => _displaySeconds = pos);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    _audio.dispose();
    super.dispose();
  }

  bool _hasLyrics(Song song) => song.notes.any((n) => n.lyric != null);

  void _playPause() => _isPlaying ? _audio.pause() : _audio.play();

  void _restart() {
    _anchorSeconds = 0;
    _sw
      ..reset()
      ..start();
    _audio.restart();
  }

  void _seek(double sec) {
    _anchorSeconds = sec;
    _sw.reset();
    if (_isPlaying) _sw.start();
    setState(() => _displaySeconds = sec);
    _audio.seek(sec);
  }

  Future<void> _setTempo(double m) async {
    await _audio.setTempoMultiplier(m);
    _anchorSeconds = 0;
    _sw
      ..stop()
      ..reset();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _displaySeconds = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    return Scaffold(
      appBar: AppBar(
        title: Text(song.title, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          _metaBar(song),
          Expanded(
            child: _ready
                ? Container(
                    color: AppColors.bg,
                    child: _hasLyrics(song)
                        ? LyricsView(
                            notes: song.notes,
                            currentIndex: _karaoke
                                ? _audio.currentNoteIndex(_displaySeconds)
                                : -1,
                            karaokeOn: _karaoke,
                          )
                        : PianoRoll(
                            notes: song.notes,
                            startTimes: _audio.startTimes,
                            totalSeconds: _audio.totalSeconds,
                            effectiveBpm: _audio.effectiveBpm,
                            currentSeconds: _displaySeconds,
                            currentIndex:
                                _audio.currentNoteIndex(_displaySeconds),
                            karaokeOn: _karaoke,
                          ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          if (_ready)
            PlayerControls(
              position: _displaySeconds,
              total: _audio.totalSeconds,
              onSeek: _seek,
              isPlaying: _isPlaying,
              onPlayPause: _playPause,
              onRestart: _restart,
              tempo: _audio.tempoMultiplier,
              onTempo: _setTempo,
              karaokeOn: _karaoke,
              onKaraoke: (v) => setState(() => _karaoke = v),
            ),
        ],
      ),
    );
  }

  Widget _metaBar(Song song) {
    final chips = <String>[
      if (song.composer != null) song.composer!,
      if (song.keySignature.isNotEmpty) song.keySignature,
      song.timeSignature,
      '♩=${song.tempoBpm}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: chips
            .map((c) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(c,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ))
            .toList(),
      ),
    );
  }
}
