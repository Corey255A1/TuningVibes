import 'package:flutter/foundation.dart';
import '../domain/app_mode.dart';
import '../domain/audio_port.dart';
import '../bridge/native_audio_adapter.dart';


/// The central orchestrator that manages mode lifecycle, audio streaming,
/// and acts as the [AppModeContext] for all registered modes.
///
/// This is the single [ChangeNotifier] provided to the widget tree.
/// Modes communicate state changes back through [notifyStateChanged].
class AppOrchestrator extends ChangeNotifier implements AppModeContext {
  final AudioInputPort _audioPort;
  final List<AppMode> _modes;

  AppMode? _currentMode;
  bool _isListening = false;


  AppOrchestrator({required List<AppMode> modes})
      : _audioPort = AudioAdapterFactory.create(),
        _modes = modes {
    // Activate the first mode by default
    if (_modes.isNotEmpty) {
      _activateMode(_modes.first);
    }
  }

  /// All registered modes
  List<AppMode> get modes => List.unmodifiable(_modes);

  /// The currently active mode
  AppMode? get currentMode => _currentMode;

  /// Whether the orchestrator is currently streaming audio
  bool get isListening => _isListening;

  // --- AppModeContext implementation ---

  @override
  int get sampleRate => _audioPort.actualSampleRate;

  @override
  Stream<List<double>> get audioStream => _audioPort.audioStream;

  @override
  void notifyStateChanged() => notifyListeners();

  // --- Mode Management ---

  /// Switch to the mode with the given [id].
  Future<void> selectMode(String id) async {
    if (_currentMode?.id == id) return;

    final nextMode = _modes.firstWhere((m) => m.id == id, orElse: () => _modes.first);

    // Deactivate current mode
    _currentMode?.onDeactivate();

    // Handle audio: stop if current mode used mic and next doesn't; restart if needed
    if (_isListening && !nextMode.requiresMicrophone) {
      await _stopAudio();
    }

    await _activateMode(nextMode);
    notifyListeners();

    // Auto-start audio if the new mode needs it and we were already listening
    if (_isListening && nextMode.requiresMicrophone) {
      // Already streaming, mode will connect on activate
    }
  }

  Future<void> _activateMode(AppMode mode) async {
    _currentMode = mode;
    mode.onActivate(this);
  }

  // --- Audio Lifecycle ---

  /// Request permission and start audio streaming.
  Future<bool> startListening() async {
    if (_isListening) return true;

    final hasPerm = await _audioPort.hasPermission();
    if (!hasPerm) {
      final granted = await _audioPort.requestPermission();
      if (!granted) return false;
    }

    const int targetSampleRate = 44100;
    final success = await _audioPort.start(targetSampleRate);
    if (success) {
      _isListening = true;
      // Re-activate current mode so it can subscribe to the live stream
      if (_currentMode != null) {
        _currentMode!.onDeactivate();
        _currentMode!.onActivate(this);
      }
      notifyListeners();
    }
    return success;
  }

  /// Stop audio streaming.
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _stopAudio();
    if (_currentMode != null) {
      _currentMode!.onDeactivate();
      _currentMode!.onActivate(this); // Re-activate in idle state
    }
    notifyListeners();
  }

  Future<void> _stopAudio() async {
    _isListening = false;
    await _audioPort.stop();
  }

  // Audio buffer processing is handled entirely by the active mode.
  // The orchestrator does not process audio directly.

  /// Toggle the audio stream on/off
  Future<void> toggleListening() async {
    if (_isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  @override
  void dispose() {
    _audioPort.stop();
    for (final mode in _modes) {
      mode.dispose();
    }
    super.dispose();
  }
}
