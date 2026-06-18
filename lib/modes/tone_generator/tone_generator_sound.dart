import 'tone_generator_sound_stub.dart'
    if (dart.library.js_interop) 'tone_generator_sound_web.dart'
    if (dart.library.io) 'tone_generator_sound_mobile.dart';

/// Platform-agnostic facade for Tone Generator sound synthesis.
class ToneGeneratorSound {
  /// Start generating a tone of a specific [frequency] in Hz,
  /// waveform [type] (e.g. 'sine', 'square', 'sawtooth', 'triangle'),
  /// and [volume] (0.0 to 1.0).
  static void start(double frequency, String type, double volume) =>
      startImpl(frequency, type, volume);

  /// Change the frequency of the playing tone dynamically.
  static void setFrequency(double frequency) => setFrequencyImpl(frequency);

  /// Change the volume of the playing tone dynamically (0.0 to 1.0).
  static void setVolume(double volume) => setVolumeImpl(volume);

  /// Change the waveform type dynamically ('sine', 'square', 'sawtooth', 'triangle').
  static void setType(String type) => setTypeImpl(type);

  /// Stop generating the tone.
  static void stop() => stopImpl();
}
