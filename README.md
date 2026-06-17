# Tuning Vibes 🎸✨

[![Flutter Test](https://github.com/tuningvibes/SleekTuner/actions/workflows/test.yml/badge.svg)](https://github.com/tuningvibes/SleekTuner)
[![Web Build](https://img.shields.io/badge/platform-web%20%7C%20android%20%7C%20ios-cyan)](https://github.com/tuningvibes/SleekTuner)
[![Dependency Policy](https://img.shields.io/badge/dependencies-zero%20third--party-brightgreen)](https://github.com/tuningvibes/SleekTuner)

**Tuning Vibes** is a high-fidelity, ultra-responsive instrument tuner built from the ground up using **Flutter & Dart**. 

By completely rejecting third-party plugins, Tuning Vibes interfaces directly with native operating system audio streams (WASAPI, AVAudioEngine, AudioRecord, and Web Audio APIs). It pipes raw PCM buffers into a custom **YIN pitch-detection engine** to deliver instant, noise-resilient calibration for guitars, basses, violins, cellos, and ukuleles.

---

## 🚀 Key Innovative Features

### 1. Zero-Dependency Hexagonal Architecture
No black-box audio packages. We wrote our own platform channels and JS interop adapters using `dart:js_interop`. The core signal processing logic remains strictly decoupled from hardware details via a clean hexagonal (ports & adapters) boundary, ensuring robust AOT compilation and lightning-fast load times.

### 2. High-Precision YIN Algorithm
Unlike primitive autocorrelation tuners that jitter or lock onto harmonics, Tuning Vibes utilizes the mathematical **YIN Algorithm**. By calculating the *cumulative mean normalized difference* of the signal, it isolates fundamental pitches with absolute precision, even for quiet pure sine tones or noisy acoustic environments.

### 3. Dynamic Low-Pass Filtering
The tuner dynamically recalibrates an digital **RC low-pass filter** based on the selected instrument tuning. When tuning a Bass, it restricts high frequencies above 200 Hz; for Violin, it expands to 1000 Hz. This eliminates high-frequency harmonic interference and guarantees stable fundamental tracking.

### 4. Interactive Pegboard & String Lock
Renders a visual headstock layout mapping string notes (3+3 or 2+2) dynamically.
- **Auto-Detect**: Tones are auto-routed and highlight the matching peg.
- **Manual Lock**: Tap any peg to hard-lock the tuner onto a single string's target frequency. This filters out adjacent string resonances in noisy stage environments.

### 5. Physics-Based "Magnetic" Needle
Our dial gauge maps cents deviation ($\pm 50$) to radial sweeps. Driven by a `TweenAnimationBuilder` using `Curves.easeOutCubic`, the needle exhibits virtual weight and inertia. When a string is tuned within a precise $\pm 3$ cent tolerance, it locks into a **vibrant green snap-state**.

### 6. Accuracy Spectrogram Waterfall
Scrolls a live horizontal trail recording pitch accuracy history over time. Color-coded (Flat: orange, Sharp: red, In-tune: green), it maps pluck intensity and tension shifts, showing you exactly how stable your string is under decay.

---

## 🛠 Directory Layout

```text
lib/
├── domain/       # Hexagonal Ports & Agnostic Note Models
├── dsp/          # Digital Signal Processing (YIN Math, Filters, RMS)
├── bridge/       # Native Platform Adapters (Kotlin, Swift, JS Interop)
└── ui/           # Custom Painters, Dial Gauge, Pegs, Waterfall, & VM
```

Detailed documentation on implementation mechanics can be found in the [`/docs`](file:///home/corey/code/TuningVibes/docs/) directory:
- [System Architecture](file:///home/corey/code/TuningVibes/docs/architecture.md)
- [YIN DSP Mathematics](file:///home/corey/code/TuningVibes/docs/dsp_yin_algorithm.md)
- [UI/UX Animations & Layout](file:///home/corey/code/TuningVibes/docs/ui_and_ux_concepts.md)

---

## ⚡ Getting Started

Ensure you have the Flutter SDK installed on your system.

### Running the Project
Compile and run on your preferred device:
```bash
# Run on connected emulator, desktop client, or local web server
flutter run

# Specifically run the Web Server (accessible on any device in the network)
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

### Running the Test Suite
Ensure our widget layout checks and math validations pass successfully:
```bash
flutter test
```

### Compiling Web Production Bundle
Generates highly optimized tree-shaken JS scripts inside `build/web`:
```bash
flutter build web
```
