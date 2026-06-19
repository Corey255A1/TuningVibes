# Modular App Mode Architecture

## Overview

TuningVibes began as a single-purpose guitar tuner. As the feature set expanded to include a **BPM Detector** and a **Metronome**, it became necessary to structure the application so that each major feature area is self-contained, independently testable, and easy to extend — without entangling unrelated concerns. The result is a plug-in-style **mode system** that treats each feature (Tuner, BPM, Metronome) as a first-class, interchangeable mode.

This document describes the architecture of that system: its core abstractions, lifecycle rules, UI wiring, and data flow.

---

## Motivation

Before the mode system was introduced, the app had a single audio pipeline wired directly to the tuner logic. Adding BPM detection would have required:

- Multiplexing the audio stream in an ad-hoc way
- Duplicating lifecycle (start/stop audio, dispose resources) across multiple places
- Cluttering the top-level widget with conditional rendering for unrelated UI states

The goal of the mode system is to make adding a new feature as simple as writing one class and registering it in `main.dart`. All audio access, lifecycle coordination, and navigation are handled centrally by the `AppOrchestrator`.

---

## Core Abstraction: `AppMode`

**File:** `lib/domain/app_mode.dart`

Every feature is represented as a concrete implementation of the abstract `AppMode` class. The interface is intentionally minimal — modes do one job and delegate everything else.

```dart
/// Abstract base class for all application modes (Tuner, BPM, Metronome, etc.)
abstract class AppMode {
  /// Unique string identifier for this mode. Used for routing and persistence.
  /// Examples: 'tuner', 'bpm', 'metronome'
  String get id;

  /// Human-readable label shown in the mode selector bar.
  String get displayName;

  /// Icon displayed in the mode selector tab.
  IconData get icon;

  /// Called by [AppOrchestrator] when this mode becomes the active mode.
  /// Use [context] to subscribe to audio streams and publish state updates.
  void onActivate(AppModeContext context);

  /// Called by [AppOrchestrator] immediately before switching to a different mode.
  /// The mode must stop processing audio and cancel any active subscriptions here.
  void onDeactivate();

  /// Called once when the mode is permanently removed (e.g., on app shutdown).
  /// Release all resources (timers, stream subscriptions, native handles).
  void dispose();

  /// Returns the widget tree for this mode's UI.
  /// Called by [RootScreen] whenever [AppOrchestrator] reports this as the active mode.
  Widget buildUI(BuildContext context);
}
```

### Key Design Rules

- **Modes do not own the audio input.** They request a stream through `AppModeContext` and release it in `onDeactivate()`.
- **Modes do not navigate.** Navigation and mode switching is the `AppOrchestrator`'s responsibility.
- **Modes own their own state notifiers.** Each mode internally manages a `ChangeNotifier` (or `ValueNotifier`) for its specific state model, which its `buildUI` widget tree listens to.

---

## `AppModeContext`

**File:** `lib/domain/app_mode_context.dart`

`AppModeContext` is passed to a mode during `onActivate()`. It acts as the mode's interface to shared application services — most importantly the microphone audio stream.

```dart
/// Provides shared services to an active [AppMode].
abstract class AppModeContext {
  /// Returns a broadcast stream of raw PCM audio samples from the microphone.
  /// The stream is already open and delivering data when [onActivate] is called.
  Stream<Float32List> get audioStream;

  /// The sample rate of the audio stream (e.g., 44100 or 48000 Hz).
  int get sampleRate;

  /// Publishes a diagnostic or status string for display in the debug overlay.
  void postDiagnostic(String message);
}
```

Modes must not cache or re-use `AppModeContext` across activate/deactivate cycles. A new context instance may be provided on each activation.

---

## `AppOrchestrator`

**File:** `lib/ui/app_orchestrator.dart`

`AppOrchestrator` is the central coordinator of the application. It extends `ChangeNotifier` and is provided at the top of the widget tree via a `ChangeNotifierProvider` (or equivalent).

### Responsibilities

| Responsibility | Details |
|---|---|
| **Owns `AudioInputPort`** | Opens and holds the single microphone stream for the lifetime of the app |
| **Manages mode registry** | Holds the list of all registered `AppMode` instances |
| **Controls mode lifecycle** | Calls `onActivate` / `onDeactivate` / `dispose` at the right times |
| **Exposes active mode** | Notifies listeners when `currentMode` changes so the UI rebuilds |

### Public Interface

```dart
class AppOrchestrator extends ChangeNotifier {
  AppOrchestrator({required List<AppMode> modes});

  /// The ordered list of all registered modes.
  List<AppMode> get modes;

  /// The currently active mode. Never null after initialization.
  AppMode get currentMode;

  /// Switches to the mode with the given [id].
  /// Calls [onDeactivate] on the outgoing mode and [onActivate] on the incoming mode.
  void switchMode(String id);

  /// Initializes audio and activates the default (first) mode.
  Future<void> initialize();

  @override
  void dispose(); // disposes all modes and closes the audio port
}
```

### Mode Switching Sequence

```
User taps mode tab
       │
       ▼
AppOrchestrator.switchMode(id)
       │
       ├─► currentMode.onDeactivate()   ← outgoing mode stops audio processing
       │
       ├─► _currentMode = newMode       ← internal state updated
       │
       ├─► newMode.onActivate(context)  ← incoming mode starts audio processing
       │
       └─► notifyListeners()            ← UI rebuilds with new mode's widget tree
```

---

## Data Flow

The following diagram describes how audio data travels from the microphone through the system to the active mode's UI:

```
┌───────────────────────────────────────────────────────────────────┐
│                        Device Hardware                            │
│                        Microphone (PCM)                           │
└────────────────────────────┬──────────────────────────────────────┘
                             │  raw PCM samples (platform channel)
                             ▼
┌────────────────────────────────────────────────────────────────────┐
│                        AudioInputPort                              │
│   lib/audio/audio_input_port.dart                                  │
│   • Opens platform mic stream                                      │
│   • Converts to Float32List chunks                                 │
│   • Exposes Stream<Float32List>                                    │
└────────────────────────────┬───────────────────────────────────────┘
                             │  Stream<Float32List>
                             ▼
┌────────────────────────────────────────────────────────────────────┐
│                       AppOrchestrator                              │
│   lib/ui/app_orchestrator.dart                                     │
│   • Wraps stream in AppModeContext                                 │
│   • Passes context to active mode via onActivate()                 │
└────────────────────────────┬───────────────────────────────────────┘
                             │  AppModeContext (contains stream)
                             ▼
┌────────────────────────────────────────────────────────────────────┐
│                        Active AppMode                              │
│   e.g., TunerMode, BpmMode, MetronomeMode                         │
│   • Subscribes to audioStream                                      │
│   • Runs domain logic (pitch detection, onset detection, etc.)     │
│   • Updates its internal state notifier                            │
└────────────────────────────┬───────────────────────────────────────┘
                             │  ChangeNotifier / ValueNotifier
                             ▼
┌────────────────────────────────────────────────────────────────────┐
│                     Mode-Specific UI Widget                        │
│   e.g., TunerScreen, BpmScreen, MetronomeScreen                   │
│   • Built by AppMode.buildUI(context)                              │
│   • Listens to mode's state notifier                               │
│   • Re-renders on state changes                                    │
└────────────────────────────────────────────────────────────────────┘
```

> **Note:** The `AudioInputPort` stream stays open for the full app lifetime. Modes subscribe and unsubscribe to the broadcast stream — they never open or close the microphone directly.

---

## UI Wiring

### `RootScreen`

**File:** `lib/ui/root_screen.dart`

`RootScreen` is the top-level scaffold. It listens to `AppOrchestrator` and:

1. Renders the `ModeSelector` navigation bar at the bottom (or top)
2. Renders the active mode's UI via `currentMode.buildUI(context)` in the body

```dart
class RootScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final orchestrator = context.watch<AppOrchestrator>();
    return Scaffold(
      body: orchestrator.currentMode.buildUI(context),
      bottomNavigationBar: ModeSelector(
        modes: orchestrator.modes,
        activeId: orchestrator.currentMode.id,
        onSelect: (id) => orchestrator.switchMode(id),
      ),
    );
  }
}
```

### `_ModeSelector`

**File:** `lib/ui/screens/root_screen.dart`

A custom, glassmorphic dropdown selection menu built from the orchestrator's `modes` list. It uses `DropdownButton HideUnderline` and custom `selectedItemBuilder` formatting to display the selected mode's icon and uppercase display name in cyan Accent. Choosing a dropdown item invokes `AppOrchestrator.selectMode(id)`.

---

## Concrete Mode Implementations

| Mode | Class | Directory | Description |
|---|---|---|---|
| Tuner | `TunerMode` | `lib/modes/tuner/` | Chromatic pitch detection via autocorrelation/YIN |
| BPM Detector | `BpmMode` | `lib/modes/bpm/` | Onset-based beat detection and BPM estimation |
| Metronome | `MetronomeMode` | `lib/modes/metronome/` | Rhythmic click generation with time signature support |

Each mode directory contains at minimum:
- `<name>_mode.dart` — the `AppMode` subclass
- `<name>_state.dart` — the immutable state model and its notifier
- `<name>_screen.dart` — the UI widget (or folder of widgets)

---

## Adding a New Mode

Adding a new mode to TuningVibes requires exactly three steps:

### Step 1 — Create the mode class

```dart
// lib/modes/spectrum/spectrum_mode.dart

class SpectrumMode extends AppMode {
  @override
  String get id => 'spectrum';

  @override
  String get displayName => 'Spectrum';

  @override
  IconData get icon => Icons.equalizer;

  @override
  void onActivate(AppModeContext context) {
    // subscribe to context.audioStream, start analysis
  }

  @override
  void onDeactivate() {
    // cancel stream subscription
  }

  @override
  void dispose() {
    // release any remaining resources
  }

  @override
  Widget buildUI(BuildContext context) => SpectrumScreen();
}
```

### Step 2 — Implement the state model and UI

Define your state class in `<name>_state.dart` and your widget tree in `<name>_screen.dart`. The UI subscribes to the mode's state notifier using `ListenableBuilder` or `context.watch`.

### Step 3 — Register in `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final orchestrator = AppOrchestrator(
    modes: [
      TunerMode(),
      BpmMode(),
      MetronomeMode(),
      SpectrumMode(), // ← add here
    ],
  );

  await orchestrator.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: orchestrator,
      child: const TuningVibesApp(),
    ),
  );
}
```

No other files need to be modified.

---

## Summary

The mode system enforces a clean separation between:

- **Audio infrastructure** (`AudioInputPort`, `AppOrchestrator`) — opens once, stays open
- **Domain logic** (each `AppMode` subclass) — subscribes on demand, processes independently
- **UI** (`RootScreen`, `ModeSelector`, per-mode screens) — driven by state notifiers, no direct audio coupling

This design makes TuningVibes straightforward to test (modes can be unit-tested with a mock `AppModeContext`), easy to extend (new modes require no changes to existing code), and resilient to feature growth.
