import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/audio_port.dart';
import '../domain/tuner_models.dart';
import '../dsp/pitch_detector.dart';
import '../bridge/native_audio_adapter.dart';

/// The state controller and ViewModel for the SleekTuner application.
class TunerViewModel extends ChangeNotifier {
  final AudioInputPort _audioPort = AudioAdapterFactory.create();
  final PitchDetector _pitchDetector = PitchDetector();

  // Settings
  double _referencePitch = 440.0; // Standard A4 in Hz
  double get referencePitch => _referencePitch;
  set referencePitch(double value) {
    _referencePitch = value;
    notifyListeners();
  }

  // Preset Instruments
  final List<Instrument> instruments = Instrument.presets;
  
  Instrument? _selectedInstrument;
  Instrument? get selectedInstrument => _selectedInstrument;

  Tuning? _selectedTuning;
  Tuning? get selectedTuning => _selectedTuning;

  InstrumentString? _selectedString; // For manual string selection mode
  InstrumentString? get selectedString => _selectedString;

  // Active state
  bool _isListening = false;
  bool get isListening => _isListening;

  TuningState _state = TuningState.idle();
  TuningState get state => _state;

  // Visual Feeds
  List<double> _waveformSamples = List<double>.filled(1024, 0.0);
  List<double> get waveformSamples => _waveformSamples;

  final List<HistoryPoint> _frequencyHistory = [];
  List<HistoryPoint> get frequencyHistory => _frequencyHistory;

  StreamSubscription<List<double>>? _audioSubscription;
  static const int sampleRate = 22050;

  // Decaying/Smoothing variables
  int _noSignalFrames = 0;
  static const int maxHoldFrames = 15; // Hold state for ~300ms of dropout to avoid needle jitter
  double _lastValidFrequency = 0.0;
  double _lastValidCents = 0.0;
  Note _lastValidNote = Note.fromMidiNumber(69);
  InstrumentString? _lastValidString;

  TunerViewModel() {
    // Default to Chromatic mode (selectedInstrument = null)
    _selectedInstrument = null;
    _selectedTuning = null;
    _selectedString = null;
  }

  /// Select chromatic mode (null instrument)
  void selectChromaticMode() {
    _selectedInstrument = null;
    _selectedTuning = null;
    _selectedString = null;
    _resetTunerState();
    notifyListeners();
  }

  /// Select an instrument and its tuning
  void selectInstrument(Instrument instrument, {Tuning? tuning}) {
    _selectedInstrument = instrument;
    _selectedTuning = tuning ?? instrument.defaultTuning;
    _selectedString = null; // Default to Auto-detect string
    _resetTunerState();
    notifyListeners();
  }

  /// Select a tuning for the current instrument
  void selectTuning(Tuning tuning) {
    if (_selectedInstrument != null) {
      _selectedTuning = tuning;
      _selectedString = null; // Reset manual string selection
      _resetTunerState();
      notifyListeners();
    }
  }

  /// Select a specific string to tune (manual string lock mode)
  /// If set to null, the tuner will auto-detect the closest string.
  void selectString(InstrumentString? string) {
    _selectedString = string;
    notifyListeners();
  }

  void _resetTunerState() {
    _state = TuningState.idle();
    _lastValidFrequency = 0.0;
    _lastValidCents = 0.0;
    _lastValidString = null;
    _noSignalFrames = maxHoldFrames;
  }

  /// Toggle listening state
  Future<void> toggleListening() async {
    if (_isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// Start streaming microphone input and running the DSP pipeline
  Future<bool> startListening() async {
    if (_isListening) return true;

    final hasPerm = await _audioPort.hasPermission();
    if (!hasPerm) {
      final granted = await _audioPort.requestPermission();
      if (!granted) return false;
    }

    final success = await _audioPort.start(sampleRate);
    if (success) {
      _isListening = true;
      _resetTunerState();
      _waveformSamples = List<double>.filled(1024, 0.0);
      _frequencyHistory.clear();
      
      _audioSubscription = _audioPort.audioStream.listen(
        _processAudioBuffer,
        onError: (err) {
          debugPrint("Audio Stream Error: $err");
          stopListening();
        },
      );
      notifyListeners();
    }
    return success;
  }

  /// Stop streaming microphone input
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioPort.stop();
    _resetTunerState();
    notifyListeners();
  }

  /// Core DSP analysis loop executed on every incoming audio buffer
  void _processAudioBuffer(List<double> buffer) {
    if (buffer.isEmpty) return;

    // 1. Maintain a rolling waveform buffer for the UI (1024 samples)
    if (_waveformSamples.length != 1024) {
      _waveformSamples = List<double>.filled(1024, 0.0);
    }
    
    // Shift old samples left and copy new ones
    final int incomingLength = buffer.length;
    if (incomingLength >= 1024) {
      _waveformSamples = buffer.sublist(incomingLength - 1024);
    } else {
      _waveformSamples.removeRange(0, incomingLength);
      _waveformSamples.addAll(buffer);
    }

    final int streamSampleRate = _audioPort.actualSampleRate;

    // 2. Perform Dynamic Low-Pass Filtering based on Selected Instrument
    List<double> filtered = buffer;
    if (_selectedInstrument != null && _selectedTuning != null) {
      // Find the highest note frequency in the current tuning to set the lowpass filter cutoff
      final double maxTuningFreq = _selectedTuning!.strings
          .map((s) => s.note.frequency)
          .reduce(max);
      
      // Cut off standard guitar around 550Hz, bass around 200Hz, violin around 1000Hz
      final double cutoff = max(maxTuningFreq * 1.5, 300.0);
      filtered = _pitchDetector.lowPassFilter(buffer, cutoff, streamSampleRate);
    }

    // 3. Detect raw fundamental frequency
    final double rawFreq = _pitchDetector.detectPitch(
      filtered,
      streamSampleRate,
      volumeThreshold: 0.003, // Lower threshold for higher sensitivity
    );

    final double amplitude = _pitchDetector.calculateRms(buffer);
    final bool hasSignal = rawFreq > 0.0;

    // 4. Update states with smoothing decay
    if (hasSignal) {
      _noSignalFrames = 0;
      _lastValidFrequency = rawFreq;

      Note closestNote;
      double cents;
      InstrumentString? matchedString;

      if (_selectedInstrument != null && _selectedTuning != null) {
        if (_selectedString != null) {
          // Manual target string mode
          matchedString = _selectedString;
          closestNote = matchedString!.note;
          cents = closestNote.centsDifference(rawFreq, referenceFrequency: _referencePitch);
        } else {
          // Auto-detect closest string in selected tuning
          InstrumentString? bestString;
          double minDiff = double.infinity;
          
          for (final s in _selectedTuning!.strings) {
            final double diff = s.note.centsDifference(rawFreq, referenceFrequency: _referencePitch).abs();
            if (diff < minDiff) {
              minDiff = diff;
              bestString = s;
            }
          }
          
          // Only snap if the frequency is within 180 cents of the string
          if (minDiff < 180.0 && bestString != null) {
            matchedString = bestString;
            closestNote = matchedString.note;
            cents = closestNote.centsDifference(rawFreq, referenceFrequency: _referencePitch);
          } else {
            // Fallback to chromatic search if no string matches closely
            closestNote = Note.fromFrequency(rawFreq, referenceFrequency: _referencePitch);
            cents = closestNote.centsDifference(rawFreq, referenceFrequency: _referencePitch);
            matchedString = null;
          }
        }
      } else {
        // Pure chromatic mode
        closestNote = Note.fromFrequency(rawFreq, referenceFrequency: _referencePitch);
        cents = closestNote.centsDifference(rawFreq, referenceFrequency: _referencePitch);
      }

      _lastValidNote = closestNote;
      _lastValidCents = cents;
      _lastValidString = matchedString;

      _state = TuningState(
        frequency: rawFreq,
        centsOffset: cents.clamp(-50.0, 50.0),
        closestNote: closestNote,
        closestString: matchedString,
        amplitude: amplitude,
        hasSignal: true,
      );

      // Record in spectrogram history
      _frequencyHistory.add(HistoryPoint(
        frequency: rawFreq,
        amplitude: amplitude,
        timestamp: DateTime.now(),
      ));
    } else {
      // Audio drop-out or quiet. Implement smoothing to prevent needle bouncing back to zero
      _noSignalFrames++;
      
      if (_noSignalFrames < maxHoldFrames && _lastValidFrequency > 0.0) {
        // Hold the previous values but mark as fading/reduced signal
        _state = TuningState(
          frequency: _lastValidFrequency,
          centsOffset: _lastValidCents,
          closestNote: _lastValidNote,
          closestString: _lastValidString,
          amplitude: amplitude * (1.0 - (_noSignalFrames / maxHoldFrames)),
          hasSignal: true,
        );
      } else {
        // Completely decay to idle state
        _state = TuningState(
          frequency: 0.0,
          centsOffset: 0.0,
          closestNote: _lastValidNote, // Keep name of last note visible but at zero Hz
          closestString: _lastValidString,
          amplitude: amplitude,
          hasSignal: false,
        );
      }
    }

    // Keep spectrogram history capped to last 150 data points
    if (_frequencyHistory.length > 150) {
      _frequencyHistory.removeRange(0, _frequencyHistory.length - 150);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _audioPort.stop();
    super.dispose();
  }
}
