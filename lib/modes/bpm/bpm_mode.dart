import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/app_mode.dart';

/// State published by the BPM detection mode.
class BpmState {
  final double bpm;
  final bool hasSignal;
  final bool isBeatFlash; // True for one frame on each detected beat
  final double confidence; // 0.0 – 1.0 consistency of inter-onset intervals
  final double amplitude;

  const BpmState({
    required this.bpm,
    required this.hasSignal,
    required this.isBeatFlash,
    required this.confidence,
    required this.amplitude,
  });

  factory BpmState.idle() => const BpmState(
        bpm: 0,
        hasSignal: false,
        isBeatFlash: false,
        confidence: 0,
        amplitude: 0,
      );
}

/// Beat detection and BPM calculation mode.
///
/// Uses energy-based onset detection on incoming audio, then computes
/// BPM from the inter-onset intervals (IOIs) of a rolling onset buffer.
class BpmMode extends AppMode {
  // Published state
  BpmState _state = BpmState.idle();
  BpmState get state => _state;

  AppModeContext? _context;
  StreamSubscription<List<double>>? _audioSubscription;
  Timer? _beatFlashTimer;

  // Onset detection parameters
  static const int _frameSize = 1024;
  static const double _onsetMultiplier = 1.35; // Short-term must exceed long-term by this factor
  static const int _minInterOnsetMs = 200; // ~300 BPM max debounce

  // State for onset detection
  double _shortTermEnergy = 0.0;
  double _longTermEnergy = 0.0;
  int _samplesSinceLastOnset = 0;
  int _samplesPerMinIoi = 0;

  // BPM calculation — rolling onset timestamp buffer
  final List<DateTime> _onsetTimestamps = [];
  final List<DateTime> _manualTapTimestamps = [];
  static const int _maxOnsets = 12;
  double _smoothBpm = 0.0;

  @override
  String get id => 'bpm';

  @override
  String get displayName => 'BPM';

  @override
  IconData get icon => Icons.speed;

  @override
  bool get requiresMicrophone => true;

  @override
  void onActivate(AppModeContext context) {
    _context = context;
    _reset();
    _audioSubscription = context.audioStream.listen(_processBuffer);
  }

  @override
  void onDeactivate() {
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _beatFlashTimer?.cancel();
    _beatFlashTimer = null;
    _context = null;
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _beatFlashTimer?.cancel();
  }

  void _reset() {
    _state = BpmState.idle();
    _shortTermEnergy = 0.0;
    _longTermEnergy = 0.0;
    _samplesSinceLastOnset = 0;
    _onsetTimestamps.clear();
    _manualTapTimestamps.clear();
    _smoothBpm = 0.0;
  }

  /// Register a manual tap for Tap Tempo functionality.
  void registerTap() {
    final now = DateTime.now();

    // Reset tap sequence if it's been more than 3 seconds since last tap
    if (_manualTapTimestamps.isNotEmpty &&
        now.difference(_manualTapTimestamps.last).inMilliseconds > 3000) {
      _manualTapTimestamps.clear();
    }

    _manualTapTimestamps.add(now);
    if (_manualTapTimestamps.length > 8) {
      _manualTapTimestamps.removeAt(0);
    }

    // Trigger beat flash visual
    _state = BpmState(
      bpm: _smoothBpm > 0 ? _smoothBpm : 120.0, // fallback display if no BPM yet
      hasSignal: true,
      isBeatFlash: true,
      confidence: 1.0,
      amplitude: _state.amplitude,
    );
    _context?.notifyStateChanged();

    // Reset flash after 100ms
    _beatFlashTimer?.cancel();
    _beatFlashTimer = Timer(const Duration(milliseconds: 100), () {
      _state = BpmState(
        bpm: _smoothBpm,
        hasSignal: _state.hasSignal,
        isBeatFlash: false,
        confidence: _state.confidence,
        amplitude: _state.amplitude,
      );
      _context?.notifyStateChanged();
    });

    if (_manualTapTimestamps.length >= 2) {
      final List<double> iois = [];
      for (int i = 1; i < _manualTapTimestamps.length; i++) {
        final double ms = _manualTapTimestamps[i]
            .difference(_manualTapTimestamps[i - 1])
            .inMilliseconds
            .toDouble();
        if (ms >= 150 && ms <= 3000) {
          iois.add(ms);
        }
      }

      if (iois.isNotEmpty) {
        final double avgIoi = iois.reduce((a, b) => a + b) / iois.length;
        final double tappedBpm = 60000.0 / avgIoi;

        // Update running smooth BPM
        _smoothBpm = tappedBpm;

        // Clear audio onsets to avoid interference, and synchronize with tap timestamps
        _onsetTimestamps.clear();
        _onsetTimestamps.addAll(_manualTapTimestamps);

        _state = BpmState(
          bpm: tappedBpm,
          hasSignal: _state.hasSignal,
          isBeatFlash: _state.isBeatFlash,
          confidence: 1.0,
          amplitude: _state.amplitude,
        );
      }
    }
    _context?.notifyStateChanged();
  }

  // --- Audio Processing ---

  void _processBuffer(List<double> buffer) {
    if (buffer.isEmpty) return;

    final int sampleRate = _context?.sampleRate ?? 44100;
    _samplesPerMinIoi = (sampleRate * _minInterOnsetMs / 1000).round();

    // Process in _frameSize chunks
    int offset = 0;
    while (offset + _frameSize <= buffer.length) {
      final frame = buffer.sublist(offset, offset + _frameSize);
      _processFrame(frame, sampleRate);
      offset += _frameSize;
    }
  }

  void _processFrame(List<double> frame, int sampleRate) {
    // RMS energy for this frame
    double sumSq = 0.0;
    for (final s in frame) {
      sumSq += s * s;
    }
    final double rms = sqrt(sumSq / frame.length);

    // Exponential moving averages: short-term (fast) and long-term (slow)
    _shortTermEnergy = 0.6 * _shortTermEnergy + 0.4 * rms;
    _longTermEnergy = 0.97 * _longTermEnergy + 0.03 * rms;

    _samplesSinceLastOnset += frame.length;

    // Onset condition: short-term energy significantly exceeds long-term average
    // and minimum inter-onset interval has passed
    if (_shortTermEnergy > _longTermEnergy * _onsetMultiplier &&
        _shortTermEnergy > 0.01 && // Minimum absolute signal level
        _samplesSinceLastOnset >= _samplesPerMinIoi) {
      _samplesSinceLastOnset = 0;
      _recordOnset();
    }

    final double amplitude = rms;
    final double computedBpm = _computeBpm();
    final double confidence = _computeConfidence();

    _state = BpmState(
      bpm: computedBpm,
      hasSignal: amplitude > 0.005,
      isBeatFlash: false, // Cleared between onsets
      confidence: confidence,
      amplitude: amplitude,
    );
    _context?.notifyStateChanged();
  }

  void _recordOnset() {
    final now = DateTime.now();
    _onsetTimestamps.add(now);
    if (_onsetTimestamps.length > _maxOnsets) {
      _onsetTimestamps.removeAt(0);
    }

    // Flash the beat indicator briefly
    _state = BpmState(
      bpm: _smoothBpm,
      hasSignal: true,
      isBeatFlash: true,
      confidence: _computeConfidence(),
      amplitude: _state.amplitude,
    );
    _beatFlashTimer?.cancel();
    _beatFlashTimer = Timer(const Duration(milliseconds: 100), () {
      _state = BpmState(
        bpm: _smoothBpm,
        hasSignal: _state.hasSignal,
        isBeatFlash: false,
        confidence: _state.confidence,
        amplitude: _state.amplitude,
      );
      _context?.notifyStateChanged();
    });
    _context?.notifyStateChanged();
  }

  double _computeBpm() {
    if (_onsetTimestamps.length < 3) return _smoothBpm;

    final List<double> iois = [];
    for (int i = 1; i < _onsetTimestamps.length; i++) {
      final double ioiMs = _onsetTimestamps[i]
          .difference(_onsetTimestamps[i - 1])
          .inMilliseconds
          .toDouble();
      // Filter out implausible IOIs (< 150ms = 400BPM, > 3000ms = 20BPM)
      if (ioiMs >= 150 && ioiMs <= 3000) {
        iois.add(ioiMs);
      }
    }

    if (iois.isEmpty) return _smoothBpm;

    final double avgIoi = iois.reduce((a, b) => a + b) / iois.length;
    final double rawBpm = 60000.0 / avgIoi;

    // Exponential smoothing
    if (_smoothBpm == 0.0) {
      _smoothBpm = rawBpm;
    } else {
      _smoothBpm = 0.25 * rawBpm + 0.75 * _smoothBpm;
    }

    return _smoothBpm;
  }

  double _computeConfidence() {
    if (_onsetTimestamps.length < 3) return 0.0;

    final List<double> iois = [];
    for (int i = 1; i < _onsetTimestamps.length; i++) {
      final double ioiMs = _onsetTimestamps[i]
          .difference(_onsetTimestamps[i - 1])
          .inMilliseconds
          .toDouble();
      if (ioiMs >= 150 && ioiMs <= 3000) {
        iois.add(ioiMs);
      }
    }

    if (iois.length < 2) return 0.0;

    final double mean = iois.reduce((a, b) => a + b) / iois.length;
    final double variance =
        iois.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / iois.length;
    final double stdDev = sqrt(variance);

    // Coefficient of variation — lower = more consistent = higher confidence
    final double cv = stdDev / mean;
    return (1.0 - cv.clamp(0.0, 1.0)).clamp(0.0, 1.0);
  }

  @override
  Widget buildUI(BuildContext context) {
    throw UnimplementedError('Use BpmModeWidget instead.');
  }
}
