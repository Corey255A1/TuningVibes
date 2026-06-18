import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/app_mode.dart';
import '../../domain/tuner_models.dart';
import '../../dsp/pitch_detector.dart';


/// State published by the Tuner mode on each audio frame.
class TunerModeState {
  final TuningState tuningState;
  final List<double> waveformSamples;
  final List<HistoryPoint> frequencyHistory;

  const TunerModeState({
    required this.tuningState,
    required this.waveformSamples,
    required this.frequencyHistory,
  });

  factory TunerModeState.idle() => TunerModeState(
        tuningState: TuningState.idle(),
        waveformSamples: List.filled(1024, 0.0),
        frequencyHistory: [],
      );
}

/// The Chromatic / Instrument Tuner mode.
///
/// Self-contained: manages its own state, DSP pipeline, and provides its UI widget.
class TunerMode extends AppMode {
  final PitchDetector _pitchDetector = PitchDetector();

  // Instrument / tuning selection
  final List<Instrument> instruments = Instrument.presets;
  Instrument? _selectedInstrument;
  Tuning? _selectedTuning;
  InstrumentString? _selectedString;

  // Reference pitch calibration
  double _referencePitch = 440.0;

  // Published state
  TunerModeState _state = TunerModeState.idle();
  TunerModeState get state => _state;

  double get referencePitch => _referencePitch;
  Instrument? get selectedInstrument => _selectedInstrument;
  Tuning? get selectedTuning => _selectedTuning;
  InstrumentString? get selectedString => _selectedString;

  // Smoothing
  int _noSignalFrames = 0;
  static const int _maxHoldFrames = 15;
  double _lastValidFrequency = 0.0;
  double _lastValidCents = 0.0;
  Note _lastValidNote = Note.fromMidiNumber(69);
  InstrumentString? _lastValidString;

  AppModeContext? _context;
  StreamSubscription<List<double>>? _audioSubscription;

  @override
  String get id => 'tuner';

  @override
  String get displayName => 'Tuner';

  @override
  IconData get icon => Icons.graphic_eq;

  @override
  bool get requiresMicrophone => true;

  @override
  void onActivate(AppModeContext context) {
    _context = context;
    _resetState();
    _audioSubscription = context.audioStream.listen(_processBuffer);
  }

  @override
  void onDeactivate() {
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _context = null;
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _audioSubscription = null;
  }

  // --- Public control methods ---

  set referencePitch(double value) {
    _referencePitch = value;
    _context?.notifyStateChanged();
  }

  void selectChromaticMode() {
    _selectedInstrument = null;
    _selectedTuning = null;
    _selectedString = null;
    _resetState();
    _context?.notifyStateChanged();
  }

  void selectInstrument(Instrument instrument, {Tuning? tuning}) {
    _selectedInstrument = instrument;
    _selectedTuning = tuning ?? instrument.defaultTuning;
    _selectedString = null;
    _resetState();
    _context?.notifyStateChanged();
  }

  void selectTuning(Tuning tuning) {
    if (_selectedInstrument != null) {
      _selectedTuning = tuning;
      _selectedString = null;
      _resetState();
      _context?.notifyStateChanged();
    }
  }

  void selectString(InstrumentString? string) {
    _selectedString = string;
    _context?.notifyStateChanged();
  }

  void _resetState() {
    _state = TunerModeState.idle();
    _lastValidFrequency = 0.0;
    _lastValidCents = 0.0;
    _lastValidString = null;
    _noSignalFrames = _maxHoldFrames;
  }

  // --- DSP Pipeline ---

  void _processBuffer(List<double> buffer) {
    if (buffer.isEmpty) return;

    final int streamSampleRate = _context?.sampleRate ?? 44100;

    // 1. Rolling waveform buffer (1024 samples for UI)
    var waveform = List<double>.from(_state.waveformSamples);
    if (waveform.length != 1024) waveform = List.filled(1024, 0.0);
    if (buffer.length >= 1024) {
      waveform = buffer.sublist(buffer.length - 1024);
    } else {
      waveform.removeRange(0, buffer.length);
      waveform.addAll(buffer);
    }

    // 2. Dynamic low-pass filter based on selected instrument
    List<double> filtered = buffer;
    if (_selectedInstrument != null && _selectedTuning != null) {
      final double maxTuningFreq = _selectedTuning!.strings
          .map((s) => s.note.frequency)
          .reduce(max);
      final double cutoff = max(maxTuningFreq * 1.5, 300.0);
      filtered = _pitchDetector.lowPassFilter(buffer, cutoff, streamSampleRate);
    }

    // 3. Fundamental frequency detection (YIN algorithm)
    final double rawFreq = _pitchDetector.detectPitch(
      filtered,
      streamSampleRate,
      volumeThreshold: 0.003,
    );

    final double amplitude = _pitchDetector.calculateRms(buffer);
    final bool hasSignal = rawFreq > 0.0;

    // 4. Note matching with smoothing decay
    final history = List<HistoryPoint>.from(_state.frequencyHistory);

    TuningState newTuningState;
    if (hasSignal) {
      _noSignalFrames = 0;
      _lastValidFrequency = rawFreq;

      Note closestNote;
      double cents;
      InstrumentString? matchedString;

      if (_selectedInstrument != null && _selectedTuning != null) {
        if (_selectedString != null) {
          matchedString = _selectedString;
          closestNote = matchedString!.note;
          cents = closestNote.centsDifference(rawFreq, referenceFrequency: _referencePitch);
        } else {
          InstrumentString? bestString;
          double minDiff = double.infinity;
          for (final s in _selectedTuning!.strings) {
            final double diff = s.note.centsDifference(rawFreq, referenceFrequency: _referencePitch).abs();
            if (diff < minDiff) {
              minDiff = diff;
              bestString = s;
            }
          }
          if (minDiff < 180.0 && bestString != null) {
            matchedString = bestString;
            closestNote = matchedString.note;
            cents = closestNote.centsDifference(rawFreq, referenceFrequency: _referencePitch);
          } else {
            closestNote = Note.fromFrequency(rawFreq, referenceFrequency: _referencePitch);
            cents = closestNote.centsDifference(rawFreq, referenceFrequency: _referencePitch);
            matchedString = null;
          }
        }
      } else {
        closestNote = Note.fromFrequency(rawFreq, referenceFrequency: _referencePitch);
        cents = closestNote.centsDifference(rawFreq, referenceFrequency: _referencePitch);
      }

      _lastValidNote = closestNote;
      _lastValidCents = cents;
      _lastValidString = matchedString;

      newTuningState = TuningState(
        frequency: rawFreq,
        centsOffset: cents.clamp(-50.0, 50.0),
        closestNote: closestNote,
        closestString: matchedString,
        amplitude: amplitude,
        hasSignal: true,
      );

      history.add(HistoryPoint(
        frequency: rawFreq,
        amplitude: amplitude,
        timestamp: DateTime.now(),
      ));
    } else {
      _noSignalFrames++;
      if (_noSignalFrames < _maxHoldFrames && _lastValidFrequency > 0.0) {
        newTuningState = TuningState(
          frequency: _lastValidFrequency,
          centsOffset: _lastValidCents,
          closestNote: _lastValidNote,
          closestString: _lastValidString,
          amplitude: amplitude * (1.0 - (_noSignalFrames / _maxHoldFrames)),
          hasSignal: true,
        );
      } else {
        newTuningState = TuningState(
          frequency: 0.0,
          centsOffset: 0.0,
          closestNote: _lastValidNote,
          closestString: _lastValidString,
          amplitude: amplitude,
          hasSignal: false,
        );
      }
    }

    if (history.length > 150) {
      history.removeRange(0, history.length - 150);
    }

    _state = TunerModeState(
      tuningState: newTuningState,
      waveformSamples: waveform,
      frequencyHistory: history,
    );

    _context?.notifyStateChanged();
  }

  @override
  Widget buildUI(BuildContext context) {
    // Delegate to the TunerModeWidget which is imported in the screen layer
    throw UnimplementedError(
      'TunerMode.buildUI is overridden by TunerModeWidget.build — '
      'use TunerModeWidget instead of calling buildUI directly.',
    );
  }
}
