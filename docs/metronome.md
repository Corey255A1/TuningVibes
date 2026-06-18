# Metronome Mode — Implementation Details

## Overview

The **Metronome** mode generates a rhythmic click track at a user-specified tempo. It supports configurable time signatures, downbeat accents, and optional subdivisions. Unlike the BPM Detector, the Metronome mode is purely an **output** mode — it does not use the microphone.

The mode lives at `lib/modes/metronome/` and is registered as `MetronomeMode` with id `'metronome'`.

---

## Time Signature Model

**File:** `lib/modes/metronome/time_signature.dart`

```dart
class TimeSignature {
  /// Number of beats per measure (e.g., 4 for 4/4, 3 for 3/4, 6 for 6/8).
  final int beatsPerMeasure;

  /// The note value that receives one beat (e.g., 4 = quarter note, 8 = eighth note).
  final int beatUnit;

  const TimeSignature(this.beatsPerMeasure, this.beatUnit);

  @override
  String toString() => '$beatsPerMeasure/$beatUnit';
}
```

### Supported Presets

| Time Signature | beatsPerMeasure | beatUnit | Character |
|---|---|---|---|
| 2/4 | 2 | 4 | March, polka |
| 3/4 | 3 | 4 | Waltz |
| 4/4 | 4 | 4 | Most common; rock, pop, jazz |
| 5/4 | 5 | 4 | Odd meter; prog rock |
| 6/8 | 6 | 8 | Compound duple; feels in 2 |
| 7/8 | 7 | 8 | Odd compound meter |
| 12/8 | 12 | 8 | Compound quadruple; blues, ballads |

### Beat Emphasis

Not all beats within a measure are equal. Beat emphasis determines which audio tone to use:

| Beat | Type | Frequency | Description |
|---|---|---|---|
| Beat 1 | **Downbeat** | 880 Hz | Highest pitch, strongest accent |
| Beats 2–N | **Regular beat** | 660 Hz | Standard click |
| Sub-beats | **Subdivision** | 440 Hz | Lighter tick, lower prominence |

---

## Tick Generation

**File:** `lib/modes/metronome/metronome_mode.dart`

The metronome uses Dart's `Timer.periodic` to schedule ticks. The interval is derived directly from the BPM:

```
tickInterval = Duration(milliseconds: (60000 / bpm).round())
```

### Beat Counter

A 1-indexed beat counter tracks position within the current measure:

```dart
int _currentBeat = 1;

void _onTick(Timer _) {
  final isDownbeat = _currentBeat == 1;
  final event = MetronomeTickEvent(
    beat: _currentBeat,
    isDownbeat: isDownbeat,
    isSubdivision: false,
  );
  _emitTick(event);
  _currentBeat = (_currentBeat % _signature.beatsPerMeasure) + 1;
}
```

### `MetronomeTickEvent`

```dart
class MetronomeTickEvent {
  /// Beat number within the measure, 1-indexed.
  final int beat;

  /// True when beat == 1 (the downbeat / first beat of the measure).
  final bool isDownbeat;

  /// True when this tick is a subdivision (half-beat, triplet, etc.), not a main beat.
  final bool isSubdivision;

  const MetronomeTickEvent({
    required this.beat,
    required this.isDownbeat,
    required this.isSubdivision,
  });
}
```

### Timer Restart on BPM Change

When BPM changes, the existing timer is cancelled and a new one is started immediately. There is no attempt to phase-lock the new timer with the old one:

```dart
void _restartTimer() {
  _timer?.cancel();
  final interval = Duration(milliseconds: (60000 / _state.bpm).round());
  _timer = Timer.periodic(interval, _onTick);
  _currentBeat = 1; // reset to downbeat
}
```

> **Note on timing accuracy:** Dart's `Timer.periodic` is not a hard real-time timer; it may drift slightly under CPU load. For most metronome use cases (practice, rehearsal) this is acceptable. If sub-millisecond accuracy is needed in the future, consider using the Web Audio API's `AudioContext.currentTime` for scheduling on web, or a dedicated audio thread on mobile.

---

## Audio Output

Because TuningVibes uses no third-party audio packages, sound synthesis is done through platform-specific mechanisms via platform channels.

### Web — Web Audio API (Oscillator Synthesis)

On the web platform, clicks are synthesized in JavaScript via a platform channel that calls into `AudioContext`:

```javascript
// dart2js interop via js_interop / package:web
function playClick(frequencyHz, durationMs) {
  const ctx = getAudioContext(); // singleton AudioContext
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();

  osc.connect(gain);
  gain.connect(ctx.destination);

  osc.type = 'sine';
  osc.frequency.setValueAtTime(frequencyHz, ctx.currentTime);

  // Envelope: instant attack, exponential decay
  gain.gain.setValueAtTime(0.8, ctx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + durationMs / 1000);

  osc.start(ctx.currentTime);
  osc.stop(ctx.currentTime + durationMs / 1000);
}
```

Frequencies used:

| Tick type | Frequency |
|---|---|
| Downbeat | 880 Hz |
| Regular beat | 660 Hz |
| Subdivision | 440 Hz |

Envelope: **attack = 0ms** (instantaneous onset), **decay = 50–80ms** (exponential ramp to near-silence), **sustain = 0**, **release = 0**. This produces a sharp, percussive click character.

### Mobile — Platform Channel + PCM

On Android and iOS, a Dart-to-native platform channel is used. The native side generates a short PCM buffer (a sine burst with the target frequency and envelope) and plays it via:

- **Android:** `AudioTrack` with `MODE_STATIC` and `STREAM_MUSIC`
- **iOS:** `AVAudioEngine` with an `AVAudioPlayerNode` playing a single-buffer `AVAudioPCMBuffer`

The PCM buffer is pre-generated at startup for each tick type (downbeat, regular, subdivision) and cached — avoiding per-tick allocation during playback.

```dart
// Dart-side platform channel call
Future<void> _playTick(TickType type) async {
  await _channel.invokeMethod('playTick', {'type': type.index});
}
```

### Tone Envelope (All Platforms)

```
Amplitude
  1.0 ┤▓
  0.8 ┤ ▓
  0.6 ┤  ▓
  0.4 ┤   ▓
  0.2 ┤    ▓▓
  0.0 ┤      ▓▓▓▓▓▓▓▓▓▓─ ─ ─ ─ ─ ─
      └──────────────────────────────►
      0ms   20ms  50ms  80ms        time
```

Attack: 0ms | Decay: ~50–80ms (exponential) | Sustain: 0 | Release: 0

---

## Subdivision Options

Subdivisions insert additional, lighter ticks between main beats. They share the timer infrastructure but fire on a faster inner timer (or by multiplying the main tick counter).

```dart
enum SubdivisionMode {
  none,      // beats only
  halves,    // every half-beat (× 2 ticks per beat)
  triplets,  // every third (× 3 ticks per beat)
  quarters,  // every quarter-beat (× 4 ticks per beat)
}
```

| Mode | Ticks per beat | Useful tempo range |
|---|---|---|
| `none` | 1 | Any |
| `halves` | 2 | 40–160 BPM |
| `triplets` | 3 | 40–120 BPM |
| `quarters` | 4 | 20–80 BPM (very slow only) |

When a subdivision mode is active, an additional inner timer fires at `interval / subdivisionFactor`. Subdivision ticks call `_emitTick` with `isSubdivision: true` and use the 440 Hz tone.

---

## BPM Input

### Controls

| Control | Range / Behavior |
|---|---|
| **Slider** | 20–240 BPM, continuous drag. Calls `_restartTimer()` on `onChangeEnd` (not on every frame). |
| **Tap Tempo** | Same rolling IOI algorithm as `BpmMode` (see `bpm_detection.md`). Resets measure counter to beat 1. |
| **− / + Buttons** | Decrement/increment BPM by 1. Long-press accelerates (repeat every 100ms). |

### BPM Constraints

```dart
const double minBpm = 20.0;
const double maxBpm = 240.0;

double _clampBpm(double bpm) => bpm.clamp(minBpm, maxBpm);
```

---

## State Model

**File:** `lib/modes/metronome/metronome_state.dart`

```dart
class MetronomeState {
  /// Current tempo in beats per minute.
  final double bpm;

  /// Active time signature.
  final TimeSignature signature;

  /// Current beat within the measure (1-indexed).
  /// 0 when the metronome is stopped.
  final int currentBeat;

  /// Whether the metronome is currently running.
  final bool isPlaying;

  /// Which subdivision mode is active.
  final SubdivisionMode subdivision;

  const MetronomeState({
    this.bpm = 120.0,
    this.signature = const TimeSignature(4, 4),
    this.currentBeat = 0,
    this.isPlaying = false,
    this.subdivision = SubdivisionMode.none,
  });

  MetronomeState copyWith({
    double? bpm,
    TimeSignature? signature,
    int? currentBeat,
    bool? isPlaying,
    SubdivisionMode? subdivision,
  }) => MetronomeState(
    bpm: bpm ?? this.bpm,
    signature: signature ?? this.signature,
    currentBeat: currentBeat ?? this.currentBeat,
    isPlaying: isPlaying ?? this.isPlaying,
    subdivision: subdivision ?? this.subdivision,
  );
}
```

---

## UI Description

**File:** `lib/modes/metronome/metronome_screen.dart`

### Layout (top to bottom)

```
┌──────────────────────────────────────────┐
│                                          │
│        ◉  ○  ○  ○   (measure bar)        │  ← beat dots: filled = current beat
│                                          │
│          ⬤  (main circle)               │  ← large circle, pulses on each beat
│                                          │
│          120   BPM                       │  ← large BPM readout
│        [ 4/4 ▾ ]  (time sig selector)   │  ← dropdown for signature presets
│                                          │
│   ─────────────────────────────────      │
│   20 ◄─────────●─────────► 240           │  ← BPM slider
│   ─────────────────────────────────      │
│                                          │
│   [ − ]   [ Tap Tempo ]   [ + ]          │  ← BPM adjustment row
│                                          │
│   Subdivision: [None ▾]                  │  ← subdivision selector
│                                          │
│          [ ▶ Play / ■ Stop ]             │  ← large play/stop toggle
│                                          │
└──────────────────────────────────────────┘
```

### Components

| Component | Behavior |
|---|---|
| **Measure Bar** | Row of `beatsPerMeasure` dots. The dot at index `currentBeat - 1` is filled/highlighted. Updates on every tick. |
| **Main Circle** | A large filled circle that pulses (briefly scales up ~1.15×) on every beat tick. Uses a fast `AnimationController` (100ms forward, 200ms reverse) triggered on each `MetronomeTickEvent`. The downbeat pulse is larger and brighter than regular beats. |
| **BPM Readout** | Displays `state.bpm.round()`. Tapping the number focuses the slider. |
| **Time Signature Selector** | A `DropdownButton` (or custom segmented picker) showing preset options. Changing it calls `MetronomeMode.setTimeSignature(ts)`. |
| **BPM Slider** | A standard `Slider` widget with `min: 20, max: 240`. Updates BPM only on drag end to avoid rapid timer restarts. |
| **− / + Buttons** | `IconButton` with `GestureDetector` for long-press repeat. |
| **Tap Tempo** | Wide `ElevatedButton`. Each tap calls `MetronomeMode.onTapTempo()`. Shows a ripple effect. |
| **Subdivision Selector** | `SegmentedButton` or `DropdownButton` with options: None, Halves, Triplets, Quarters. |
| **Play / Stop** | A large toggle button. When stopped, `currentBeat` resets to 0 and all beat indicators clear. |

---

## File Structure

```
lib/modes/metronome/
├── metronome_mode.dart       # AppMode subclass, timer logic, tick emission
├── metronome_state.dart      # MetronomeState, SubdivisionMode, TimeSignature
└── metronome_screen.dart     # MetronomeScreen widget and all UI subcomponents
```

---

## Key Implementation Notes

- **No audio packages:** All sound synthesis goes through a single `MethodChannel` named `'com.tuningvibes/audio'`. The native implementation is in `android/app/src/main/kotlin/.../AudioPlugin.kt` and `ios/Runner/AudioPlugin.swift`.
- **Timer drift:** `Timer.periodic` drifts over time. For practice use, this is acceptable. For a future "strict timing" mode, consider scheduling ticks using `AudioContext.currentTime` on web or a dedicated audio thread with `AudioRecord`/`AVAudioEngine` pull callback on mobile.
- **Stopping cleanly:** When `isPlaying` transitions to `false`, cancel the timer immediately. Do not wait for the next tick. Reset `_currentBeat = 1` so the next play starts from the downbeat.
- **Background audio:** If the app is backgrounded on mobile, the `Timer` will pause. This is expected behavior; the metronome is not designed for background playback in the current version.
