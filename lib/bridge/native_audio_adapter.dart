import '../domain/audio_port.dart';
import 'audio_adapter_stub.dart'
    if (dart.library.js_interop) 'audio_adapter_web.dart'
    if (dart.library.io) 'audio_adapter_mobile.dart';

/// Unified factory to create platform-specific [AudioInputPort]s at runtime.
class AudioAdapterFactory {
  /// Create the platform-specific audio input adapter.
  static AudioInputPort create() {
    return getAudioAdapter();
  }
}
