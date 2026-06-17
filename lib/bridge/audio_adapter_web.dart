import 'dart:async';
import 'dart:js_interop';
import '../domain/audio_port.dart';

@JS('audioRecorder.start')
external JSPromise<JSNumber> jsStart(int sampleRate);

@JS('audioRecorder.stop')
external void jsStop();

@JS('audioRecorder.setOnAudioProcess')
external void jsSetOnAudioProcess(JSFunction callback);

/// Web implementation of [AudioInputPort] using browser JS interop.
class AudioAdapterWeb implements AudioInputPort {
  final StreamController<List<double>> _controller = StreamController<List<double>>.broadcast();
  int _actualSampleRate = 22050;

  @override
  Stream<List<double>> get audioStream => _controller.stream;

  @override
  Future<bool> hasPermission() async {
    // In web, attempting to start the microphone triggers the permission dialog.
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    return true;
  }

  @override
  Future<bool> start(int sampleRate) async {
    // Define the audio callback that JS calls with Float32 samples
    final JSFunction callback = (JSArray samples) {
      final int len = samples.length;
      final List<double> dartSamples = List<double>.filled(len, 0.0);
      
      final dartList = samples.toDart;
      for (int i = 0; i < len; i++) {
        final item = dartList[i];
        if (item != null) {
          dartSamples[i] = (item as JSNumber).toDartDouble;
        }
      }
      
      if (_controller.hasListener && !_controller.isClosed) {
        _controller.add(dartSamples);
      }
    }.toJS;

    jsSetOnAudioProcess(callback);

    try {
      final JSNumber actualRate = await jsStart(sampleRate).toDart;
      final int rate = actualRate.toDartInt;
      if (rate == 0) return false;
      _actualSampleRate = rate;
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      jsStop();
    } catch (_) {}
  }

  @override
  int get actualSampleRate => _actualSampleRate;
}

AudioInputPort getAudioAdapter() => AudioAdapterWeb();
