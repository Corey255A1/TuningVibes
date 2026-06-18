# Tone Generator Mode — Implementation Details

## Overview

The **Tone Generator** mode outputs synthesized audio tones at user-specified frequencies or musical notes. It supports fine-tuning, quick octave shifting, logarithmic frequency sweeps, volume control, and multiple waveform types. Like the Metronome, the Tone Generator is purely an **output** mode and does not require microphone access.

The feature resides in `lib/modes/tone_generator/` and is registered under the `ToneGeneratorMode` class with the unique identifier `'tone_generator'`.

---

## Pitch and Frequency Model

The Tone Generator uses a unified model that maps musical notes (note names, octaves) and cents offsets to standard frequencies.

### Frequency Calculation Formula

The target frequency $f$ in Hertz is calculated from the MIDI note number $d$ and fine-tuning cents offset $c$ (where 100 cents = 1 semitone) relative to A4 (MIDI note 69, $440.0$ Hz):

$$f = 440.0 \times 2^{\frac{d - 69 + \frac{c}{100}}{12}}$$

In Dart:
```dart
double calculateFrequency(int midi, double cents) {
  return 440.0 * pow(2.0, (midi - 69.0 + cents / 100.0) / 12.0);
}
```

### Symmetric Mapping

When the user modifies the frequency directly in Hz, the mode automatically resolves the closest MIDI note and cents offset:

1. **Calculate MIDI number:**
   $$d = \lfloor 69 + 12 \log_2\left(\frac{f}{440}\right) \rceil$$
2. **Calculate cents difference:**
   $$c = 1200 \log_2\left(\frac{f}{f_{note}}\right)$$

This allows seamless, bi-directional control between note-based selectors and frequency sweep sliders.

---

## Platform-Agnostic Audio Facade

**Files:**
- `lib/modes/tone_generator/tone_generator_sound.dart`
- `lib/modes/tone_generator/tone_generator_sound_stub.dart`
- `lib/modes/tone_generator/tone_generator_sound_web.dart`
- `lib/modes/tone_generator/tone_generator_sound_mobile.dart`

To ensure compliance with the **no third-party audio libraries** rule, the system delegates synthesis to platform-conditional files.

### 1. Web Implementation (Web Audio API)

Web is the primary target. We declare the `window.toneGenerator` JavaScript object inside `/web/index.html` to manage a sustained oscillator.

```javascript
window.toneGenerator = {
  audioContext: null,
  oscillator: null,
  gainNode: null,
  isPlaying: false,

  _ensureContext() { ... },
  start(frequency, type, volume) { ... },
  setFrequency(frequency) { ... },
  setVolume(volume) { ... },
  setType(type) { ... },
  stop() { ... }
};
```

Dart interop is established in `tone_generator_sound_web.dart` using modern JS annotations:
```dart
import 'dart:js_interop';

@JS('toneGenerator.start')
external void _jsStart(double frequency, JSString type, double volume);

@JS('toneGenerator.setFrequency')
external void _jsSetFrequency(double frequency);

@JS('toneGenerator.setVolume')
external void _jsSetVolume(double volume);

@JS('toneGenerator.setType')
external void _jsSetType(JSString type);

@JS('toneGenerator.stop')
external void _jsStop();
```

### 2. Mobile Implementation

Calls are sent via a dedicated platform channel `com.tuningvibes/tone_out`. If the platform handler is not implemented (or has not yet been registered natively), it falls back silently via `.catchError((_) {})` to avoid application crashes.

---

## Waveform Types

The Tone Generator supports four primary synthesis waveforms:

| Waveform | Character | Harmonic Content | Ideal For |
|---|---|---|---|
| **Sine** (`sine`) | Pure, smooth | Fundamental frequency only | Tuning string instruments |
| **Triangle** (`triangle`) | Soft, flute-like | Odd harmonics (decaying $1/n^2$) | Sweet reference pitches |
| **Sawtooth** (`sawtooth`) | Bright, buzzy | All harmonics ($1/n$) | Rich synth leads, string ensemble testing |
| **Square** (`square`) | Hollow, clarinet-like | Odd harmonics ($1/n$) | Retro 8-bit sounds, acoustic tests |

---

## UI and Visual Design

**File:** `lib/modes/tone_generator/tone_generator_mode_widget.dart`

The UI matches the premium, dark glassmorphic theme (`#0D0F13` background, `cyanAccent` accents, and translucent cards).

### Responsive Layout

- **Narrow/Portrait screens**: Rendered in a single-column layout using a scrolling column: visualizer card $\rightarrow$ pitch card $\rightarrow$ settings card $\rightarrow$ central play button.
- **Wide/Landscape screens**: Renders in a two-column row. Left column hosts the visualizer and play button; right column hosts controls for fine-tuning, frequency sweep, volume, and waveform chips.

### Animated Waveform Visualizer

We paint the selected waveform shape in real time using a `CustomPainter` that draws a continuous stroke over the width of the canvas. To keep it feeling like an organic oscilloscope display:
1. An `AnimationController` runs continuously when sound is active, shifting the horizontal `phase` value.
2. A fading envelope (`edgeFade = sin(ratio * pi)`) is applied to taper the amplitude to 0 near the edges, preventing visual clipping at the card borders.

Mathematical waveforms painted:
- **Sine**: $v = \sin(\theta)$
- **Square**: $v = \text{sign}(\sin(\theta))$
- **Triangle**: $v = \frac{2}{\pi} \arcsin(\sin(\theta))$
- **Sawtooth**: $v = 2 \times \frac{\theta \bmod 2\pi}{2\pi} - 1$

---

## Architecture Integration

1. **`main.dart`**: Register `ToneGeneratorMode()` alongside other modes in the `AppOrchestrator` initial list.
2. **`root_screen.dart`**: Route the `'tone_generator'` mode identifier to render `ToneGeneratorModeWidget` inside the mode container.
