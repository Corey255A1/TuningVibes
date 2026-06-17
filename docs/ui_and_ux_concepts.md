# UI & UX Design Concepts

SleekTuner is designed to be cool, modern, and highly interactive. Rather than displaying numbers in static text boxes, it translates real-time audio analysis into smooth, intuitive graphic elements.

This document details the UI/UX design concepts, animations, and interactive controls used in the app.

---

## 1. Responsive Centered Layout (Mobile-First Desktop)

Tuners are primarily designed for mobile screens, which are tall and narrow. When a mobile UI is rendered full-screen on a wide desktop browser, elements stretch horizontally, making dial gauges and pegboards appear bloated and awkward.

To solve this:
- We constrain the tuner content width to a maximum of **480 pixels** using `ConstrainedBox`.
- On desktop monitors, the tuner is centered horizontally on the page as a sleek "hardware device card" casting a soft ambient drop-shadow.
- On mobile screens, the layout automatically expands to fill the full screen width natively.
- The outer body uses a deep `#08090B` black, while the tuner card uses a `#0D0F13` slate-gray to make the neon glowing widgets pop.

---

## 2. The "Magnetic" Needle Gauge

The needle gauge ([`lib/ui/widgets/needle_painter.dart`](file:///home/corey/code/TuningVibes/lib/ui/widgets/needle_painter.dart)) indicates how flat or sharp a string is relative to the target note.

```text
       [0 Cents (In Tune)]
              |
      -30     |     +30
        \     |     /
         \    |    /
   -50 -----[Hub]----- +50 (Cents)
   (Flat)             (Sharp)
```

### Radial Mapping
Cents deviation ($\pm 50$) is mapped to a radial arc spanning a sweep angle of $120^\circ$:
- **-50 cents** maps to $210^\circ$ (flat left, or $-60^\circ$ from vertical).
- **0 cents** maps to $270^\circ$ (pointing straight up).
- **+50 cents** maps to $330^\circ$ (sharp right, or $+60^\circ$ from vertical).

### Tween Animation Smoothing (Inertia)
If the needle immediately jumped to the raw cent values returned by the YIN algorithm, it would jitter rapidly from frame to frame due to background noise. 

To make the gauge feel like a high-quality physical mechanical needle, we wrap the custom painter in a `TweenAnimationBuilder`. When a new cents offset is detected, the widget interpolates the value over **90 milliseconds** using a `Curves.easeOutCubic` ease curve. This simulates **inertia** (physical weight), yielding a smooth sweep. If the signal drops out, the needle slowly drifts back to center over **350 milliseconds** instead of snapping back instantly.

### Magnetic Snapping (Green Lock State)
If the string is within $\pm 3$ cents of the target note, the app enters a **locked** state:
- The dial needle glows a vibrant neon green.
- A glowing green segment fills the center zone of the arc.
- This visual snapping mirrors the feeling of a magnet pulling the tuning peg into place, giving the user strong, immediate feedback that their string is tuned.

---

## 3. Real-Time Waveform Background

To confirm that the app is actively listening even when no note is being played, we draw a live waveform widget ([`lib/ui/widgets/waveform_painter.dart`](file:///home/corey/code/TuningVibes/lib/ui/widgets/waveform_painter.dart)) running behind the center panel at low opacity.

- It plots the raw microphone buffer (1024 samples) as a continuous bezier line.
- To prevent the waveform edges from clipping harshly at the screen boundaries, we apply a **sine window function** inside the paint loop:
  $$y_{\text{plot}} = y_{\text{center}} + x[i] \times \text{amplitude} \times \sin\left(\frac{\pi i}{N-1}\right)$$
  This naturally tapers the waveform amplitudes down to zero at the left and right edges.
- When audio is detected, the line glows in cyan (or green/red depending on the tuning state). When quiet, it pulses gently.

---

## 4. Interactive Pegboard Headstock

When an instrument (e.g. Guitar) is selected, the pegboard ([`lib/ui/widgets/instrument_pegs.dart`](file:///home/corey/code/TuningVibes/lib/ui/widgets/instrument_pegs.dart)) renders the tuning pegs arranged 3+3 (Gibson style) or 2+2 (bass/ukulele style) around a central headstock neck.

### Real-Time Peg Highlight
- In **Auto-Detect** mode, the view model matches the detected pitch against the standard frequencies of all strings.
- The string peg that matches most closely lights up in neon cyan (or green if in-tune), giving the user visual confirmation of which string they are currently tuning.

### Interactive Peg Lock (Manual Mode)
In loud rooms or when tuning instruments with a lot of resonance, auto-detect can get confused by other strings vibrating.
- Users can tap any peg on the headstock diagram to **lock** the tuner to that specific string.
- When locked, the target note becomes fixed, and the active peg shows a white selection border.
- Tapping the active peg again releases the lock and returns the tuner to **Auto-Detect** mode.

---

## 5. Scrolling Spectrogram Waterfall

The waterfall display ([`lib/ui/widgets/waterfall_painter.dart`](file:///home/corey/code/TuningVibes/lib/ui/widgets/waterfall_painter.dart)) plots the last 150 historical pitch measurements scrolling horizontally from right (newest) to left (oldest).

- The horizontal line representing the center ($Y = \text{height}/2$) is the target pitch (0 cents deviation).
- The vertical offset shows whether the pitch was sharp ($Y < \text{center}$) or flat ($Y > \text{center}$).
- Points are color-coded in real-time:
  * **Green** for locked/in-tune ($\le \pm 3$ cents).
  * **Orange** for flat notes.
  * **Red** for sharp notes.
- The vertical height/opacity of the trailing lines reflects the sound intensity (amplitude) of the pluck, showing the attack and decay of the note over time.
- This chart lets the user visually analyze how stable their string tension is (whether it slips immediately after a pluck).
