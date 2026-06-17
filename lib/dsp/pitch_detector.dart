import 'dart:math';

/// A high-performance, pure Dart Digital Signal Processing library for pitch detection.
class PitchDetector {
  /// Apply a simple digital RC low-pass filter to suppress high harmonics.
  /// [cutoffHz] is the cutoff frequency, e.g., 500 Hz for guitars.
  List<double> lowPassFilter(List<double> input, double cutoffHz, int sampleRate) {
    if (input.isEmpty) return [];
    
    final double dt = 1.0 / sampleRate;
    final double rc = 1.0 / (2.0 * pi * cutoffHz);
    final double alpha = dt / (rc + dt);
    
    final List<double> output = List<double>.filled(input.length, 0.0);
    output[0] = input[0];
    
    for (int i = 1; i < input.length; i++) {
      output[i] = output[i - 1] + alpha * (input[i] - output[i - 1]);
    }
    return output;
  }

  /// Calculates the Root Mean Square (RMS) amplitude of the audio buffer.
  /// Represents the volume level.
  double calculateRms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sumSq = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sumSq += samples[i] * samples[i];
    }
    return sqrt(sumSq / samples.length);
  }

  /// Detects the fundamental pitch (frequency in Hz) using an optimized YIN algorithm.
  ///
  /// [samples] should be normalized floats in the range [-1.0, 1.0].
  /// [sampleRate] is the actual capture rate of the incoming audio stream.
  /// [minFreq] and [maxFreq] define the search limits (e.g. 40 Hz to 1000 Hz).
  /// [volumeThreshold] is the minimum RMS below which it is considered silence.
  double detectPitch(
    List<double> samples,
    int sampleRate, {
    double minFreq = 40.0,
    double maxFreq = 1000.0,
    double volumeThreshold = 0.003,
  }) {
    final double rms = calculateRms(samples);
    if (rms < volumeThreshold) {
      return -1.0; // Silence or too quiet
    }

    final int len = samples.length;
    // Downsample by 2 to make it ultra-fast and robust against high frequency noise
    final int dsLen = len ~/ 2;
    final List<double> dsSamples = List<double>.filled(dsLen, 0.0);
    for (int i = 0; i < dsLen; i++) {
      dsSamples[i] = (samples[i * 2] + samples[i * 2 + 1]) / 2.0;
    }
    final int dsSampleRate = sampleRate ~/ 2;

    // Determine lag ranges for downsampled rate
    // Lag (samples) = sampleRate / Frequency
    final int minLag = (dsSampleRate / maxFreq).floor();
    final int maxLag = min(dsLen ~/ 2, (dsSampleRate / minFreq).ceil());
    
    if (dsLen < maxLag * 2) {
      return -1.0; // Not enough samples
    }

    final int w = dsLen - maxLag; // Integration window size
    
    // Step 1: Difference function
    // d[tau] = sum_{j=0}^{W-1} (x[j] - x[j+tau])^2
    final List<double> d = List<double>.filled(maxLag, 0.0);
    for (int tau = 0; tau < maxLag; tau++) {
      double sum = 0.0;
      for (int j = 0; j < w; j++) {
        final double diff = dsSamples[j] - dsSamples[j + tau];
        sum += diff * diff;
      }
      d[tau] = sum;
    }

    // Step 2: Cumulative mean normalized difference function
    final List<double> dPrime = List<double>.filled(maxLag, 0.0);
    dPrime[0] = 1.0;
    double runningSum = 0.0;
    for (int tau = 1; tau < maxLag; tau++) {
      runningSum += d[tau];
      dPrime[tau] = d[tau] / (runningSum / tau);
    }

    // Step 3: Absolute thresholding
    // Find the first tau that drops below the YIN threshold
    int tauSelected = -1;
    const double yinThreshold = 0.15; // Standard YIN threshold
    
    for (int tau = minLag; tau < maxLag; tau++) {
      if (dPrime[tau] < yinThreshold) {
        tauSelected = tau;
        // Keep scanning to find the local minimum
        while (tau + 1 < maxLag && dPrime[tau + 1] < dPrime[tau]) {
          tau++;
          tauSelected = tau;
        }
        break;
      }
    }

    // Fallback: If no lag falls below the threshold, choose the global minimum
    if (tauSelected == -1) {
      double minVal = double.infinity;
      for (int tau = minLag; tau < maxLag; tau++) {
        if (dPrime[tau] < minVal) {
          minVal = dPrime[tau];
          tauSelected = tau;
        }
      }
      // If the global minimum is still extremely poor, reject the pitch
      if (minVal > 0.35) {
        return -1.0;
      }
    }

    // Step 4: Parabolic interpolation for sub-sample accuracy
    double preciseLag = tauSelected.toDouble();
    if (tauSelected > 0 && tauSelected < maxLag - 1) {
      final double alpha = dPrime[tauSelected - 1];
      final double beta = dPrime[tauSelected];
      final double gamma = dPrime[tauSelected + 1];
      
      final double denom = alpha - 2.0 * beta + gamma;
      if (denom.abs() > 1e-5) {
        preciseLag = tauSelected + (alpha - gamma) / (2.0 * denom);
      }
    }

    final double frequency = dsSampleRate / preciseLag;

    // Sanity check
    if (frequency < minFreq || frequency > maxFreq) {
      return -1.0;
    }

    return frequency;
  }
}
