import 'dart:async';

/// Abstract port representing the audio recording source.
/// Follows hexagonal architecture to keep the DSP/UI decoupled from the platform.
abstract class AudioInputPort {
  /// Stream emitting real-time audio samples normalized in the range [-1.0, 1.0].
  Stream<List<double>> get audioStream;

  /// Check if the platform has recording permission.
  Future<bool> hasPermission();

  /// Request recording permission from the user.
  Future<bool> requestPermission();

  /// Start streaming microphone audio at the specified [sampleRate].
  Future<bool> start(int sampleRate);

  /// Stop streaming microphone audio.
  Future<void> stop();

  /// The actual sample rate of the running audio stream.
  int get actualSampleRate;
}
