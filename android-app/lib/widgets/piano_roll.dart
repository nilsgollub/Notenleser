import 'package:flutter/material.dart';
import '../models/note_event.dart';
import '../theme.dart';

/// Piano-Roll-Darstellung der Melodie mit einem goldenen Karaoke-Cursor,
/// der der Wiedergabeposition folgt. Die aktuell klingende Note leuchtet auf.
class PianoRoll extends StatefulWidget {
  const PianoRoll({
    super.key,
    required this.notes,
    required this.startTimes,
    required this.totalSeconds,
    required this.effectiveBpm,
    required this.currentSeconds,
    required this.currentIndex,
    required this.karaokeOn,
  });

  final List<NoteEvent> notes;
  final List<double> startTimes;
  final double totalSeconds;
  final double effectiveBpm;
  final double currentSeconds;
  final int currentIndex;
  final bool karaokeOn;

  @override
  State<PianoRoll> createState() => _PianoRollState();
}

class _PianoRollState extends State<PianoRoll> {
  final _scroll = ScrollController();
  static const double _pps = 80; // Pixel pro Sekunde
  static const double _rowHeight = 13;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  ({int minMidi, int maxMidi}) _pitchRange() {
    int? lo, hi;
    for (final n in widget.notes) {
      if (n.isRest) continue;
      final m = n.midiNote;
      lo = (lo == null) ? m : (m < lo ? m : lo);
      hi = (hi == null) ? m : (m > hi ? m : hi);
    }
    lo ??= 60;
    hi ??= 72;
    return (minMidi: lo - 1, maxMidi: hi + 1);
  }

  @override
  Widget build(BuildContext context) {
    final range = _pitchRange();
    final secPerBeat = 60.0 / widget.effectiveBpm;
    final contentWidth = (widget.totalSeconds * _pps) + 48;
    final cursorX = widget.currentSeconds * _pps + 24;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportW = constraints.maxWidth;

        if (widget.karaokeOn && _scroll.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scroll.hasClients) return;
            final target = (cursorX - viewportW / 2)
                .clamp(0.0, _scroll.position.maxScrollExtent);
            _scroll.jumpTo(target);
          });
        }

        return SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: widget.karaokeOn
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          child: CustomPaint(
            size: Size(contentWidth, constraints.maxHeight),
            painter: _PianoRollPainter(
              notes: widget.notes,
              startTimes: widget.startTimes,
              secPerBeat: secPerBeat,
              pps: _pps,
              rowHeight: _rowHeight,
              minMidi: range.minMidi,
              maxMidi: range.maxMidi,
              currentIndex: widget.karaokeOn ? widget.currentIndex : -1,
              cursorX: cursorX,
              showCursor: widget.karaokeOn,
            ),
          ),
        );
      },
    );
  }
}

class _PianoRollPainter extends CustomPainter {
  _PianoRollPainter({
    required this.notes,
    required this.startTimes,
    required this.secPerBeat,
    required this.pps,
    required this.rowHeight,
    required this.minMidi,
    required this.maxMidi,
    required this.currentIndex,
    required this.cursorX,
    required this.showCursor,
  });

  final List<NoteEvent> notes;
  final List<double> startTimes;
  final double secPerBeat;
  final double pps;
  final double rowHeight;
  final int minMidi;
  final int maxMidi;
  final int currentIndex;
  final double cursorX;
  final bool showCursor;

  @override
  void paint(Canvas canvas, Size size) {
    final bandH = (maxMidi - minMidi + 1) * rowHeight;
    final top = ((size.height - bandH) / 2).clamp(0.0, size.height);

    double yFor(int midi) => top + (maxMidi - midi) * rowHeight;

    // Dezente Zeilenlinien je Oktave (C)
    final linePaint = Paint()..color = AppColors.border;
    for (int midi = minMidi; midi <= maxMidi; midi++) {
      if (midi % 12 == 0) {
        final y = yFor(midi) + rowHeight;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }

    // Noten
    final notePaint = Paint()..color = AppColors.primary.withOpacity(0.85);
    final activePaint = Paint()..color = AppColors.accent;
    final glowPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (var i = 0; i < notes.length; i++) {
      final n = notes[i];
      if (n.isRest) continue;
      final x = startTimes[i] * pps + 24;
      final w = (n.durationBeats * secPerBeat * pps - 2).clamp(3.0, double.infinity);
      final y = yFor(n.midiNote);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y + 1, w, rowHeight - 2),
        const Radius.circular(3),
      );
      final isActive = i == currentIndex;
      if (isActive) {
        canvas.drawRRect(rect.inflate(3), glowPaint);
        canvas.drawRRect(rect, activePaint);
      } else {
        canvas.drawRRect(rect, notePaint);
      }
    }

    // Karaoke-Cursor
    if (showCursor) {
      final cursorPaint = Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2;
      canvas.drawLine(
          Offset(cursorX, 0), Offset(cursorX, size.height), cursorPaint);
      canvas.drawCircle(Offset(cursorX, 8), 5, Paint()..color = AppColors.accent);
    }
  }

  @override
  bool shouldRepaint(covariant _PianoRollPainter old) =>
      old.currentIndex != currentIndex ||
      old.cursorX != cursorX ||
      old.showCursor != showCursor ||
      old.notes != notes;
}
