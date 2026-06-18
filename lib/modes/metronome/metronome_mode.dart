import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/app_mode.dart';
import 'metronome_sound.dart';

/// Time signature definition.
class TimeSignature {
  final int beatsPerMeasure; // Numerator, e.g. 3 in "3/4"
  final int beatUnit; // Denominator, e.g. 4 in "3/4"

  const TimeSignature(this.beatsPerMeasure, this.beatUnit);

  String get label => '$beatsPerMeasure/$beatUnit';

  static const List<TimeSignature> presets = [
    TimeSignature(2, 4),
    TimeSignature(3, 4),
    TimeSignature(4, 4),
    TimeSignature(5, 4),
    TimeSignature(6, 8),
    TimeSignature(7, 8),
    TimeSignature(12, 8),
  ];
}

/// How many sub-divisions to play within each beat.
enum SubdivisionMode {
  none('None'),
  halves('Halves (÷2)'),
  triplets('Triplets (÷3)'),
  quarters('Quarters (÷4)');

  final String label;
  const SubdivisionMode(this.label);
}

/// Tick event emitted by the metronome timer.
class MetronomeTick {
  final int beat; // 1-indexed beat within the measure
  final bool isDownbeat; // True when beat == 1
  final bool isSubdivision; // True for sub-division ticks
  final int subdivisionIndex; // 0 = the beat itself, 1+ = sub-division

  const MetronomeTick({
    required this.beat,
    required this.isDownbeat,
    required this.isSubdivision,
    required this.subdivisionIndex,
  });
}

/// State published by the Metronome mode on each tick.
class MetronomeState {
  final double bpm;
  final TimeSignature timeSignature;
  final int currentBeat; // 1-indexed
  final bool isPlaying;
  final SubdivisionMode subdivision;
  final bool isTickFlash; // True on each tick for visual feedback

  const MetronomeState({
    required this.bpm,
    required this.timeSignature,
    required this.currentBeat,
    required this.isPlaying,
    required this.subdivision,
    required this.isTickFlash,
  });

  factory MetronomeState.idle() => const MetronomeState(
        bpm: 120,
        timeSignature: TimeSignature(4, 4),
        currentBeat: 1,
        isPlaying: false,
        subdivision: SubdivisionMode.none,
        isTickFlash: false,
      );
}

/// The Metronome mode.
///
/// Generates precise rhythmic clicks at the specified BPM using
/// a Dart [Timer] and platform-native or Web Audio synthesis.
class MetronomeMode extends AppMode {
  MetronomeState _state = MetronomeState.idle();
  MetronomeState get state => _state;

  AppModeContext? _context;
  Timer? _tickTimer;
  Timer? _flashTimer;

  // Tap tempo state
  final List<DateTime> _tapTimestamps = [];

  int _currentBeat = 1;
  int _currentSubDiv = 0; // 0 = beat, 1..N = sub-division ticks

  @override
  String get id => 'metronome';

  @override
  String get displayName => 'Metronome';

  @override
  IconData get icon => Icons.av_timer;

  @override
  bool get requiresMicrophone => false;

  @override
  void onActivate(AppModeContext context) {
    _context = context;
    // Metronome does not need audio input — no stream subscription
  }

  @override
  void onDeactivate() {
    _stopTimer();
    _context = null;
  }

  @override
  void dispose() {
    _stopTimer();
  }

  // --- Public controls ---

  void setBpm(double bpm) {
    final double clamped = bpm.clamp(20.0, 240.0);
    if ((clamped - _state.bpm).abs() < 0.1) return;
    _state = MetronomeState(
      bpm: clamped,
      timeSignature: _state.timeSignature,
      currentBeat: _state.currentBeat,
      isPlaying: _state.isPlaying,
      subdivision: _state.subdivision,
      isTickFlash: false,
    );
    if (_state.isPlaying) _restartTimer();
    _context?.notifyStateChanged();
  }

  void setTimeSignature(TimeSignature sig) {
    _state = MetronomeState(
      bpm: _state.bpm,
      timeSignature: sig,
      currentBeat: 1,
      isPlaying: _state.isPlaying,
      subdivision: _state.subdivision,
      isTickFlash: false,
    );
    _currentBeat = 1;
    _currentSubDiv = 0;
    if (_state.isPlaying) _restartTimer();
    _context?.notifyStateChanged();
  }

  void setSubdivision(SubdivisionMode mode) {
    _state = MetronomeState(
      bpm: _state.bpm,
      timeSignature: _state.timeSignature,
      currentBeat: _state.currentBeat,
      isPlaying: _state.isPlaying,
      subdivision: mode,
      isTickFlash: false,
    );
    if (_state.isPlaying) _restartTimer();
    _context?.notifyStateChanged();
  }

  void togglePlay() {
    if (_state.isPlaying) {
      _stopTimer();
      _state = MetronomeState(
        bpm: _state.bpm,
        timeSignature: _state.timeSignature,
        currentBeat: 1,
        isPlaying: false,
        subdivision: _state.subdivision,
        isTickFlash: false,
      );
      _currentBeat = 1;
      _currentSubDiv = 0;
    } else {
      _currentBeat = 1;
      _currentSubDiv = 0;
      _state = MetronomeState(
        bpm: _state.bpm,
        timeSignature: _state.timeSignature,
        currentBeat: 1,
        isPlaying: true,
        subdivision: _state.subdivision,
        isTickFlash: false,
      );
      _startTimer();
    }
    _context?.notifyStateChanged();
  }

  /// Register a tap for tap-tempo calculation.
  void registerTap() {
    final now = DateTime.now();
    _tapTimestamps.add(now);
    if (_tapTimestamps.length > 8) _tapTimestamps.removeAt(0);

    if (_tapTimestamps.length >= 2) {
      final List<double> iois = [];
      for (int i = 1; i < _tapTimestamps.length; i++) {
        final double ms = _tapTimestamps[i]
            .difference(_tapTimestamps[i - 1])
            .inMilliseconds
            .toDouble();
        if (ms >= 200 && ms <= 3000) iois.add(ms);
      }
      if (iois.isNotEmpty) {
        final double avgIoi = iois.reduce((a, b) => a + b) / iois.length;
        setBpm(60000.0 / avgIoi);
      }
    }
    _context?.notifyStateChanged();
  }

  // --- Timer management ---

  int get _subdivCount {
    switch (_state.subdivision) {
      case SubdivisionMode.none:
        return 1;
      case SubdivisionMode.halves:
        return 2;
      case SubdivisionMode.triplets:
        return 3;
      case SubdivisionMode.quarters:
        return 4;
    }
  }

  Duration get _tickInterval {
    final double beatMs = 60000.0 / _state.bpm;
    final double tickMs = beatMs / _subdivCount;
    return Duration(microseconds: (tickMs * 1000).round());
  }

  void _startTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(_tickInterval, (_) => _onTick());
    // Immediately fire the first tick
    _onTick();
  }

  void _restartTimer() {
    _stopTimer();
    _currentBeat = 1;
    _currentSubDiv = 0;
    _startTimer();
  }

  void _stopTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _flashTimer?.cancel();
    _flashTimer = null;
  }

  void _onTick() {
    final bool isBeat = _currentSubDiv == 0;
    final bool isDownbeat = isBeat && _currentBeat == 1;
    final bool isSubDiv = !isBeat;

    // Play sound
    final int soundType = isDownbeat ? 0 : (isSubDiv ? 2 : 1);
    MetronomeSound.playClick(soundType);

    // Publish state with flash
    _state = MetronomeState(
      bpm: _state.bpm,
      timeSignature: _state.timeSignature,
      currentBeat: _currentBeat,
      isPlaying: true,
      subdivision: _state.subdivision,
      isTickFlash: isBeat,
    );
    _context?.notifyStateChanged();

    // Schedule flash reset
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 80), () {
      _state = MetronomeState(
        bpm: _state.bpm,
        timeSignature: _state.timeSignature,
        currentBeat: _state.currentBeat,
        isPlaying: _state.isPlaying,
        subdivision: _state.subdivision,
        isTickFlash: false,
      );
      _context?.notifyStateChanged();
    });

    // Advance beat/subdivision counters
    _currentSubDiv++;
    if (_currentSubDiv >= _subdivCount) {
      _currentSubDiv = 0;
      _currentBeat++;
      if (_currentBeat > _state.timeSignature.beatsPerMeasure) {
        _currentBeat = 1;
      }
    }
  }

  @override
  Widget buildUI(BuildContext context) {
    throw UnimplementedError('Use MetronomeModeWidget instead.');
  }
}
