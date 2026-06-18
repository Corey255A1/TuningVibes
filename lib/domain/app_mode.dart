import 'dart:async';
import 'package:flutter/material.dart';

/// The context provided to each [AppMode] when activated.
/// Modes use this to request audio streams and notify the orchestrator of state changes.
abstract class AppModeContext {
  /// The current audio sample rate (determined at runtime by the audio adapter)
  int get sampleRate;

  /// A stream of audio sample buffers from the microphone.
  /// Only available when the orchestrator has started listening.
  Stream<List<double>> get audioStream;

  /// Request that the UI be rebuilt (equivalent to calling notifyListeners on the orchestrator).
  void notifyStateChanged();
}

/// Abstract base class for all application modes (Tuner, BPM, Metronome, etc.).
///
/// To add a new mode:
/// 1. Create a new class extending [AppMode]
/// 2. Implement all abstract members
/// 3. Register the mode in the list passed to [AppOrchestrator] in `main.dart`
///
/// Each mode is self-contained: it owns its state, processes audio (if needed),
/// and provides its own UI widget.
abstract class AppMode {
  /// Unique identifier for this mode. Used internally for state keying.
  String get id;

  /// Human-readable name shown in the mode selector.
  String get displayName;

  /// Icon for this mode in the selector bar.
  IconData get icon;

  /// Whether this mode requires microphone access.
  bool get requiresMicrophone;

  /// Called when this mode becomes active.
  /// The [context] provides access to the audio stream and notification mechanism.
  void onActivate(AppModeContext context);

  /// Called when this mode is being deactivated (another mode is selected).
  /// Modes should cancel any active subscriptions here.
  void onDeactivate();

  /// Builds the primary content widget for this mode.
  /// Called within a [ListenableBuilder] on the orchestrator.
  Widget buildUI(BuildContext context);

  /// Releases all resources. Called when the orchestrator is disposed.
  void dispose();
}
