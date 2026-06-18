import 'metronome_sound_stub.dart'
    if (dart.library.js_interop) 'metronome_sound_web.dart'
    if (dart.library.io) 'metronome_sound_mobile.dart';

/// Platform-agnostic facade for metronome click sound synthesis.
class MetronomeSound {
  /// Play a click of the given [type]:
  /// - 0 = downbeat accent (highest pitch)
  /// - 1 = regular beat
  /// - 2 = subdivision (softest)
  static void playClick(int type) => playClickImpl(type);
}
