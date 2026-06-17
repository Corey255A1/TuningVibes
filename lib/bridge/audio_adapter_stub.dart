import '../domain/audio_port.dart';

/// Stub implementation of [AudioInputPort] for platforms that don't support audio capture.
class AudioAdapterStub implements AudioInputPort {
  @override
  Stream<List<double>> get audioStream => const Stream<List<double>>.empty();

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> start(int sampleRate) async => false;

  @override
  Future<void> stop() async {}

  @override
  int get actualSampleRate => 22050;
}

AudioInputPort getAudioAdapter() => AudioAdapterStub();
