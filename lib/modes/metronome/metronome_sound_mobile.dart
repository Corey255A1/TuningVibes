import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Mobile implementation: synthesizes a click as a PCM sine burst
/// and plays it via the AudioOutput platform channel.
///
/// Falls back to a no-op if the channel is unavailable.
void playClickImpl(int type) {
  // Generate a short sine burst (50ms) at the appropriate frequency
  const int sampleRate = 44100;
  const double durationSec = 0.055;
  final int numSamples = (sampleRate * durationSec).round();

  final List<double> freqs = [1100.0, 750.0, 500.0];
  final List<double> gains = [0.85, 0.6, 0.35];
  final double freq = freqs[type.clamp(0, 2)];
  final double gain = gains[type.clamp(0, 2)];

  final Float32List pcm = Float32List(numSamples);
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    // Exponential decay envelope
    final double envelope = exp(-t / durationSec * 4.0);
    pcm[i] = (sin(2.0 * pi * freq * t) * gain * envelope).toDouble();
  }

  // Send PCM to platform channel
  const channel = MethodChannel('com.tuningvibes/audio_out');
  channel.invokeMethod('playPcm', {
    'samples': pcm.buffer.asUint8List(),
    'sampleRate': sampleRate,
  }).catchError((_) {
    // Platform channel not available — silent fallback
  });
}
