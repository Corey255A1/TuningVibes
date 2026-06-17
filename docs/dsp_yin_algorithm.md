# Digital Signal Processing & The YIN Algorithm

SleekTuner relies on a high-precision, low-latency Digital Signal Processing (DSP) pipeline implemented entirely in pure Dart in [`lib/dsp/pitch_detector.dart`](file:///home/corey/code/TuningVibes/lib/dsp/pitch_detector.dart). 

This document provides a detailed breakdown of the mathematical operations involved in preparing, filtering, and analyzing the microphone audio to estimate the fundamental frequency ($f_0$) of a stringed instrument.

---

## 1. The Audio Preparation Chain

Before the pitch detection calculations occur, raw audio buffers are processed to remove noise and unwanted frequency bands.

### Step A: Root Mean Square (RMS) Amplitude Check
To prevent the analyzer from calculating pitch on random room noise or silence, the Root Mean Square (RMS) energy is computed:
$$x_{\text{RMS}} = \sqrt{\frac{1}{N} \sum_{n=0}^{N-1} x[n]^2}$$
If $x_{\text{RMS}} < 0.003$ (the sensitivity threshold), the buffer is immediately rejected as silence.

### Step B: Dynamic low-pass filtering
Musical instruments produce strong **harmonics** (multiples of the fundamental frequency). An E2 guitar string (82.4 Hz) produces harmonics at 164.8 Hz, 247.2 Hz, etc. If the harmonics are louder than the fundamental tone, a naive tuner will jump to the octave.

To prevent this, the view model calculates a dynamic cutoff frequency based on the selected instrument (e.g., standard guitar has a highest string E4 at 329.6 Hz, so we apply a low-pass filter with a cutoff of $329.6 \times 1.5 \approx 500$ Hz).

We apply a digital RC low-pass filter:
$$y[n] = y[n-1] + \alpha (x[n] - y[n-1])$$
Where $\alpha$ is the smoothing factor derived from the sample rate ($f_s$) and cutoff frequency ($f_c$):
$$\Delta t = \frac{1}{f_s}$$
$$RC = \frac{1}{2 \pi f_c}$$
$$\alpha = \frac{\Delta t}{RC + \Delta t}$$

### Step C: Downsampling
To reduce CPU load and double frequency resolution at low ranges, the buffer is downsampled by a factor of 2. Each pair of samples is averaged to act as an anti-aliasing pre-filter:
$$x_{\text{down}}[i] = \frac{x[2i] + x[2i+1]}{2}$$
Downsampling halves the sampling rate:
$$f_{s,\text{down}} = \frac{f_s}{2}$$
If the browser captures audio at 48000 Hz, the YIN algorithm runs at 24000 Hz. If it captures at 22050 Hz, YIN runs at 11025 Hz.

---

## 2. The YIN Pitch Detection Algorithm

The YIN algorithm is a standard for fundamental frequency estimation. It improves upon autocorrelation by using a cumulative mean normalized difference function, which eliminates amplitude-dependence and filters out the self-similarity peak at lag-0.

### Step 1: The Difference Function
Standard autocorrelation measures how similar a signal is to itself at different lags ($\tau$). YIN uses the **squared difference function** $d(\tau)$, which measures how much the signal *differs* from itself at lag $\tau$:
$$d(\tau) = \sum_{j=0}^{W-1} (x[j] - x[j+\tau])^2$$
Where:
- $\tau$ is the lag in samples (searched from $\tau_{\text{min}} = f_{s,\text{down}} / 1000$ to $\tau_{\text{max}} = f_{s,\text{down}} / 40$).
- $W$ is the integration window size ($W = N_{\text{down}} - \tau_{\text{max}}$).

At the true fundamental period, $x[j] \approx x[j+\tau]$, so the difference $d(\tau)$ drops close to 0.

### Step 2: The Cumulative Mean Normalized Difference Function
Although $d(\tau)$ drops close to 0 at the true period, it is also 0 at $\tau = 0$. In noisy signals, $d(\tau)$ can also dip early at sub-harmonics. To prevent the algorithm from choosing these incorrect lags, YIN normalizes the difference function:
$$d'(\tau) = \begin{cases} 1 & \text{if } \tau = 0 \\ \frac{d(\tau)}{\frac{1}{\tau} \sum_{j=1}^{\tau} d(j)} & \text{otherwise} \end{cases}$$
By dividing the difference by the running average of preceding differences, YIN forces $d'(\tau)$ to remain close to $1.0$ at small lags, and only drop low at the first significant period.

### Step 3: Absolute Thresholding
We search for the first lag $\tau$ where the normalized difference drops below a threshold (standard YIN uses $\theta = 0.15$):
$$d'(\tau) < 0.15$$
Once $d'(\tau)$ falls below $0.15$, we continue scanning forward to find the local minimum (the bottom of the valley) to get the most accurate period estimate. 

*Fallback*: If no lag falls below the threshold, the algorithm scans the entire range and selects the global minimum of $d'(\tau)$. If this global minimum exceeds $0.35$, it is rejected as noise.

### Step 4: Parabolic Interpolation
Since audio is digitized at discrete time steps, the true fundamental period might lie between sample indices (e.g. $\tau = 50.43$ samples). To achieve sub-sample resolution (required to detect cents-level deviations), we fit a parabola through the three points surrounding the selected local minimum ($\tau_{\text{selected}}$):
$$\alpha = d'[\tau_{\text{selected}}-1]$$
$$\beta = d'[\tau_{\text{selected}}]$$
$$\gamma = d'[\tau_{\text{selected}}+1]$$
The precise lag is estimated as:
$$\tau_{\text{precise}} = \tau_{\text{selected}} + \frac{\alpha - \gamma}{2(\alpha - 2\beta + \gamma)}$$

### Step 5: Frequency Calculation
Finally, we calculate the estimated fundamental frequency:
$$f_0 = \frac{f_{s,\text{down}}}{\tau_{\text{precise}}}$$
This estimated frequency is passed to the view model to match notes and display the cents offset.
