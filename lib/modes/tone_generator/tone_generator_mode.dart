import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/app_mode.dart';
import '../../domain/tuner_models.dart'; // To use Note
import 'tone_generator_sound.dart';

/// State of the Tone Generator mode.
class ToneGeneratorState {
  final double frequency; // Target frequency in Hz
  final int midiNumber; // MIDI note number
  final double centsOffset; // Fine-tuning offset (-50 to +50 cents)
  final String waveformType; // 'sine', 'square', 'sawtooth', 'triangle'
  final double volume; // 0.0 to 1.0
  final bool isPlaying;

  const ToneGeneratorState({
    required this.frequency,
    required this.midiNumber,
    required this.centsOffset,
    required this.waveformType,
    required this.volume,
    required this.isPlaying,
  });

  factory ToneGeneratorState.idle() => const ToneGeneratorState(
        frequency: 440.0,
        midiNumber: 69, // A4
        centsOffset: 0.0,
        waveformType: 'sine',
        volume: 0.5,
        isPlaying: false,
      );

  /// Helper to get the associated Note object
  Note get note => Note.fromMidiNumber(midiNumber);
}

/// Tone Generator AppMode implementation.
class ToneGeneratorMode extends AppMode {
  ToneGeneratorState _state = ToneGeneratorState.idle();
  ToneGeneratorState get state => _state;

  AppModeContext? _context;

  @override
  String get id => 'tone_generator';

  @override
  String get displayName => 'Tone Gen';

  @override
  IconData get icon => Icons.waves;

  @override
  bool get requiresMicrophone => false;

  @override
  void onActivate(AppModeContext context) {
    _context = context;
  }

  @override
  void onDeactivate() {
    stop();
    _context = null;
  }

  @override
  void dispose() {
    stop();
  }

  /// Start playing the tone with current parameters.
  void start() {
    if (_state.isPlaying) return;
    _state = ToneGeneratorState(
      frequency: _state.frequency,
      midiNumber: _state.midiNumber,
      centsOffset: _state.centsOffset,
      waveformType: _state.waveformType,
      volume: _state.volume,
      isPlaying: true,
    );
    ToneGeneratorSound.start(_state.frequency, _state.waveformType, _state.volume);
    _context?.notifyStateChanged();
  }

  /// Stop playing the tone.
  void stop() {
    if (!_state.isPlaying) return;
    _state = ToneGeneratorState(
      frequency: _state.frequency,
      midiNumber: _state.midiNumber,
      centsOffset: _state.centsOffset,
      waveformType: _state.waveformType,
      volume: _state.volume,
      isPlaying: false,
    );
    ToneGeneratorSound.stop();
    _context?.notifyStateChanged();
  }

  /// Toggle play/stop state.
  void togglePlay() {
    if (_state.isPlaying) {
      stop();
    } else {
      start();
    }
  }

  /// Set the frequency directly in Hz, recomputing midiNumber and centsOffset.
  void setFrequency(double freq) {
    final double clampedFreq = freq.clamp(20.0, 5000.0);
    
    // Find closest note
    final Note closestNote = Note.fromFrequency(clampedFreq);
    final int midi = closestNote.midiNumber;
    final double cents = closestNote.centsDifference(clampedFreq);

    _state = ToneGeneratorState(
      frequency: clampedFreq,
      midiNumber: midi,
      centsOffset: cents.clamp(-50.0, 50.0),
      waveformType: _state.waveformType,
      volume: _state.volume,
      isPlaying: _state.isPlaying,
    );

    if (_state.isPlaying) {
      ToneGeneratorSound.setFrequency(clampedFreq);
    }
    _context?.notifyStateChanged();
  }

  /// Set the MIDI number, updating frequency based on centsOffset.
  void setMidiNumber(int midi) {
    final int clampedMidi = midi.clamp(21, 108); // A0 (27.5Hz) to C8 (4186Hz)
    final double freq = _calculateFrequency(clampedMidi, _state.centsOffset);

    _state = ToneGeneratorState(
      frequency: freq,
      midiNumber: clampedMidi,
      centsOffset: _state.centsOffset,
      waveformType: _state.waveformType,
      volume: _state.volume,
      isPlaying: _state.isPlaying,
    );

    if (_state.isPlaying) {
      ToneGeneratorSound.setFrequency(freq);
    }
    _context?.notifyStateChanged();
  }

  /// Set cents offset for fine-tuning, updating frequency.
  void setCentsOffset(double cents) {
    final double clampedCents = cents.clamp(-50.0, 50.0);
    final double freq = _calculateFrequency(_state.midiNumber, clampedCents);

    _state = ToneGeneratorState(
      frequency: freq,
      midiNumber: _state.midiNumber,
      centsOffset: clampedCents,
      waveformType: _state.waveformType,
      volume: _state.volume,
      isPlaying: _state.isPlaying,
    );

    if (_state.isPlaying) {
      ToneGeneratorSound.setFrequency(freq);
    }
    _context?.notifyStateChanged();
  }

  /// Set waveform type.
  void setWaveformType(String type) {
    if (_state.waveformType == type) return;
    _state = ToneGeneratorState(
      frequency: _state.frequency,
      midiNumber: _state.midiNumber,
      centsOffset: _state.centsOffset,
      waveformType: type,
      volume: _state.volume,
      isPlaying: _state.isPlaying,
    );

    if (_state.isPlaying) {
      ToneGeneratorSound.setType(type);
    }
    _context?.notifyStateChanged();
  }

  /// Set volume.
  void setVolume(double vol) {
    final double clampedVol = vol.clamp(0.0, 1.0);
    if ((_state.volume - clampedVol).abs() < 0.001) return;
    _state = ToneGeneratorState(
      frequency: _state.frequency,
      midiNumber: _state.midiNumber,
      centsOffset: _state.centsOffset,
      waveformType: _state.waveformType,
      volume: clampedVol,
      isPlaying: _state.isPlaying,
    );

    if (_state.isPlaying) {
      ToneGeneratorSound.setVolume(clampedVol);
    }
    _context?.notifyStateChanged();
  }

  /// Helper to calculate frequency in Hz from MIDI number and cents offset.
  double _calculateFrequency(int midi, double cents) {
    // f = 440 * 2^((midi - 69 + cents/100) / 12)
    return 440.0 * pow(2.0, (midi - 69.0 + cents / 100.0) / 12.0);
  }

  @override
  Widget buildUI(BuildContext context) {
    throw UnimplementedError('Use ToneGeneratorModeWidget instead.');
  }
}
