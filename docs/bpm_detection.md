# BPM Detection Mode — Implementation Details

## Overview

The **BPM Detection** mode listens to microphone input in real time, identifies rhythmic onset events (the attack of each beat), and uses those events to estimate the current tempo in **Beats Per Minute (BPM)**. It is designed to work on live audio — instruments, drum machines, music playback — without requiring a steady or metronomic source.

The mode lives at `lib/modes/bpm/` and is registered as `BpmMode` with id `'bpm'`.

---

## Onset Detection Algorithm

An **onset** is a moment in audio where energy increases sharply — the start of a beat, a drum hit, a plucked string, a hand clap. The algorithm detects these events from the raw PCM stream.

### 1. Frame the Audio

Incoming audio samples are accumulated into overlapping analysis frames:

- **Frame size:** 1024 samples (~23ms at 44100 Hz)
- **Hop size:** 512 samples (~12ms at 44100 Hz) — 50% overlap

This gives a new analysis result approximately every 12ms, which is fast enough for tempo detection up to ~300 BPM.

```dart
// Pseudocode — accumulate samples and slide the window
void _processChunk(Float32List samples) {
  _buffer.addAll(samples);
  while (_buffer.length >= frameSize) {
    final frame = _buffer.sublist(0, frameSize);
    _analyzeFrame(frame);
    _buffer.removeRange(0, hopSize);
  }
}
```

### 2. Compute RMS Energy Per Frame

For each frame, compute the **Root Mean Square (RMS)** energy:

```
RMS = sqrt( (1/N) * Σ sample[i]² )
```

```dart
double _computeRms(List<double> frame) {
  final sumSq = frame.fold(0.0, (acc, s) => acc + s * s);
  return math.sqrt(sumSq / frame.length);
}
```

RMS is a reliable, low-overhead measure of instantaneous signal energy that avoids the cost of FFT.

### 3. Track Running Averages

Two exponential moving averages (EMAs) of RMS energy are maintained:

| Average | Time constant | Purpose |
|---|---|---|
| **Short-term EMA** | α = 0.5 | Tracks recent, immediate energy |
| **Long-term EMA** | α = 0.05 | Tracks background energy level |

```dart
_shortTermEnergy = alpha_short * rms + (1 - alpha_short) * _shortTermEnergy;
_longTermEnergy  = alpha_long  * rms + (1 - alpha_long)  * _longTermEnergy;
```

The long-term average provides an adaptive noise floor that adjusts to different room conditions and signal levels.

### 4. Onset Detection Threshold

An onset is flagged when:

```
shortTermEnergy > longTermEnergy * onsetMultiplier
```

The default `onsetMultiplier` is **1.3** (configurable). This means the short-term energy must exceed the background level by at least 30% to register as an onset.

```dart
const double onsetMultiplier = 1.3;

bool _checkOnset() {
  return _shortTermEnergy > (_longTermEnergy * onsetMultiplier);
}
```

### 5. Inter-Onset Debounce

To prevent the same beat from being detected multiple times (e.g., on multiple overtone peaks), a **minimum inter-onset interval (IOI)** is enforced:

- **Minimum IOI:** 200ms (corresponding to a maximum of 300 BPM)

```dart
const Duration _minInterOnset = Duration(milliseconds: 200);

void _handlePotentialOnset(DateTime now) {
  if (_lastOnsetTime == null ||
      now.difference(_lastOnsetTime!) >= _minInterOnset) {
    _lastOnsetTime = now;
    _recordOnset(now);
  }
}
```

---

## BPM Calculation

Once onsets are detected, BPM is estimated from the timing intervals between them.

### 1. Rolling Onset Buffer

The last **N = 8** onset timestamps are kept in a circular buffer. Eight onsets provides enough data to compute a stable average without adding too much latency.

```dart
final Queue<DateTime> _onsetTimes = Queue();
const int _maxOnsets = 8;

void _recordOnset(DateTime time) {
  _onsetTimes.add(time);
  if (_onsetTimes.length > _maxOnsets) _onsetTimes.removeFirst();
  if (_onsetTimes.length >= 2) _computeBpm();
}
```

### 2. Compute Inter-Onset Intervals (IOIs)

Convert the buffer of timestamps into a list of consecutive time differences in milliseconds:

```dart
List<double> _computeIois() {
  final times = _onsetTimes.toList();
  return List.generate(
    times.length - 1,
    (i) => times[i + 1].difference(times[i]).inMilliseconds.toDouble(),
  );
}
```

### 3. Outlier Rejection

IOIs outside a plausible tempo range are discarded before averaging:

| Limit | Value | Equivalent BPM |
|---|---|---|
| Minimum IOI | 150ms | 400 BPM (upper bound) |
| Maximum IOI | 3000ms | 20 BPM (lower bound) |

```dart
final validIois = iois.where((ioi) => ioi >= 150 && ioi <= 3000).toList();
if (validIois.isEmpty) return; // not enough valid data
```

### 4. Average IOI → BPM

```dart
final avgIoi = validIois.reduce((a, b) => a + b) / validIois.length;
final rawBpm = 60000.0 / avgIoi;
```

### 5. Exponential Smoothing

To prevent the displayed BPM from jumping erratically between detections, an exponential moving average is applied:

```
smoothBpm = α * rawBpm + (1 - α) * smoothBpm
```

- **Alpha (α):** 0.25 — biases toward the historical estimate, provides smooth output

```dart
const double _alpha = 0.25;
_smoothBpm = _alpha * rawBpm + (1 - _alpha) * _smoothBpm;
```

The smoothed BPM is what gets published to the UI state.

### 6. Confidence Metric

A **confidence score** (0.0–1.0) reflects the consistency of the detected IOIs. It is computed as:

```
stddev = standard deviation of validIois
confidence = clamp(1.0 - (stddev / avgIoi), 0.0, 1.0)
```

A confidence near 1.0 means the IOIs are very consistent (steady rhythm). A confidence near 0.0 means the timing is erratic and the BPM estimate is unreliable.

---

## Tap Tempo Fallback

When the audio signal is ambiguous or absent, the user can tap the screen to provide beats manually. Tap Tempo tracks manual taps in an independent `_manualTapTimestamps` buffer to prevent old audio-detected onsets from polluting or diluting the tapped tempo.

```dart
void registerTap() {
  final now = DateTime.now();

  // Reset tap sequence if it's been more than 3 seconds since last tap
  if (_manualTapTimestamps.isNotEmpty &&
      now.difference(_manualTapTimestamps.last).inMilliseconds > 3000) {
    _manualTapTimestamps.clear();
  }

  _manualTapTimestamps.add(now);

  if (_manualTapTimestamps.length >= 2) {
    // Calculates BPM based on manual taps
    final avgIoi = _computeAverageIoi(_manualTapTimestamps);
    final tappedBpm = 60000.0 / avgIoi;
    
    // Updates running smooth BPM directly
    _smoothBpm = tappedBpm;
    
    // Clears old audio onsets to avoid interference, and synchronize with tap timestamps
    _onsetTimestamps.clear();
    _onsetTimestamps.addAll(_manualTapTimestamps);
  }
}
```

By clearing and seeding the main onset buffer (`_onsetTimestamps`) with the manual tap sequence, BpmMode ensures a clean handoff between manual tapping and microphone audio analysis. Taps also immediately trigger a 100ms flash indicator visual feedback.

---

## State Model

**File:** `lib/modes/bpm/bpm_state.dart`

```dart
class BpmState {
  /// Current estimated tempo, in beats per minute.
  /// 0.0 if no tempo has been established.
  final double bpm;

  /// True if there is sufficient input signal to attempt detection.
  final bool hasSignal;

  /// True for one UI frame immediately after an onset is detected.
  /// Used to flash the beat indicator dot.
  final bool isBeatDetected;

  /// IOI consistency score in [0.0, 1.0].
  /// Higher values indicate a more stable, reliable BPM estimate.
  final double confidence;

  const BpmState({
    this.bpm = 0.0,
    this.hasSignal = false,
    this.isBeatDetected = false,
    this.confidence = 0.0,
  });

  BpmState copyWith({
    double? bpm,
    bool? hasSignal,
    bool? isBeatDetected,
    double? confidence,
  }) => BpmState(
    bpm: bpm ?? this.bpm,
    hasSignal: hasSignal ?? this.hasSignal,
    isBeatDetected: isBeatDetected ?? this.isBeatDetected,
    confidence: confidence ?? this.confidence,
  );
}
```

The `BpmMode` class holds a `ValueNotifier<BpmState>` that its `buildUI` widget tree listens to via `ValueListenableBuilder`.

---

## UI Description

**File:** `lib/modes/bpm/bpm_screen.dart`

The BPM screen is designed to be readable at a glance during performance.

### Layout (top to bottom)

```
┌──────────────────────────────────────────┐
│          Signal Level Meter              │  ← thin horizontal bar, top edge
│                                          │
│              ●  (beat dot)               │  ← pulses white/accent on each onset
│                                          │
│               128                        │  ← large animated BPM number
│              BPM                         │
│                                          │
│         ████████░░  Confidence           │  ← stability bar (0–100%)
│                                          │
│         [ Tap Tempo ]                    │  ← large tap target button
└──────────────────────────────────────────┘
```

### Components

| Component | Behavior |
|---|---|
| **BPM Number** | Displays `smoothBpm.round()`. Animates scale briefly on each new estimate. Shows `--` when `bpm == 0`. |
| **Beat Dot** | A circular indicator that flashes to full brightness on `isBeatDetected == true`, then fades back over ~150ms using an `AnimationController`. |
| **Signal Level Meter** | A horizontal progress bar driven by the current RMS value. Goes green → yellow → red as level increases. |
| **Confidence Bar** | A labeled progress bar driven by `BpmState.confidence`. Shown in muted color below 0.4 to visually warn of instability. |
| **Tap Tempo Button** | Full-width button at the bottom. Calls `BpmMode.onTapTempo()` on press. Also shows a brief ripple animation on tap. |

---

## File Structure

```
lib/modes/bpm/
├── bpm_mode.dart        # AppMode subclass, audio subscription, onset/BPM logic
├── bpm_state.dart       # BpmState data class
└── bpm_screen.dart      # BpmScreen widget, all UI components
```

---

## Algorithm Summary

```
PCM audio stream
       │
       ▼ accumulate into 1024-sample frames (512-sample hop)
       │
       ▼ compute RMS per frame
       │
       ▼ update short-term EMA (α=0.5) and long-term EMA (α=0.05)
       │
       ▼ shortTerm > longTerm × 1.3  AND  gap > 200ms?
       │
       YES → record onset timestamp
       │
       ▼ collect last 8 timestamps
       │
       ▼ compute IOIs, reject outliers (< 150ms or > 3000ms)
       │
       ▼ avgIoi = mean(validIois)
       │
       ▼ rawBpm = 60000 / avgIoi
       │
       ▼ smoothBpm = 0.25 × rawBpm + 0.75 × prevSmooth
       │
       ▼ publish BpmState → UI
```
