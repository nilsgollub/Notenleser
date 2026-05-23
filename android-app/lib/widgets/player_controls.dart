import 'package:flutter/material.dart';
import '../theme.dart';

class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.position,
    required this.total,
    required this.onSeek,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onRestart,
    required this.tempo,
    required this.onTempo,
    required this.karaokeOn,
    required this.onKaraoke,
  });

  final double position;
  final double total;
  final ValueChanged<double> onSeek;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onRestart;
  final double tempo;
  final ValueChanged<double> onTempo;
  final bool karaokeOn;
  final ValueChanged<bool> onKaraoke;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  late double _tempoDraft = widget.tempo;

  @override
  void didUpdateWidget(PlayerControls old) {
    super.didUpdateWidget(old);
    if (old.tempo != widget.tempo) _tempoDraft = widget.tempo;
  }

  String _fmt(double s) {
    if (s.isNaN || s < 0) s = 0;
    final m = (s ~/ 60);
    final sec = (s % 60).floor().toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final safeTotal = widget.total <= 0 ? 1.0 : widget.total;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fortschritt
          Row(
            children: [
              Text(_fmt(widget.position),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: widget.position.clamp(0, safeTotal),
                    max: safeTotal,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.input,
                    onChanged: widget.onSeek,
                  ),
                ),
              ),
              Text(_fmt(widget.total),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          // Hauptbedienung
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 28,
                onPressed: widget.onRestart,
                icon: const Icon(Icons.replay, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  iconSize: 34,
                  color: Colors.white,
                  onPressed: widget.onPlayPause,
                  icon: Icon(widget.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 26,
                onPressed: () => widget.onKaraoke(!widget.karaokeOn),
                tooltip: 'Karaoke-Modus',
                icon: Icon(
                  Icons.lyrics_outlined,
                  color: widget.karaokeOn
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tempo (erst beim Loslassen anwenden – Neusynthese ist teuer)
          Row(
            children: [
              const Icon(Icons.speed, size: 18, color: AppColors.textSecondary),
              Expanded(
                child: Slider(
                  value: _tempoDraft,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  activeColor: AppColors.textSecondary,
                  inactiveColor: AppColors.input,
                  onChanged: (v) => setState(() => _tempoDraft = v),
                  onChangeEnd: widget.onTempo,
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('${(_tempoDraft * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
