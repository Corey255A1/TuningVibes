import 'dart:async';
import 'package:flutter/services.dart';
import '../domain/audio_port.dart';

/// Mobile (Android/iOS) implementation of [AudioInputPort] using MethodChannel and EventChannel.
class AudioAdapterMobile implements AudioInputPort {
  static const MethodChannel _controlChannel = MethodChannel('com.tuningvibes/control');
  static const EventChannel _audioChannel = EventChannel('com.tuningvibes/audio');

  final StreamController<List<double>> _controller = StreamController<List<double>>.broadcast();
  StreamSubscription? _subscription;
  int _actualSampleRate = 22050;

  @override
  Stream<List<double>> get audioStream => _controller.stream;

  @override
  Future<bool> hasPermission() async {
    try {
      final bool? hasPerm = await _controlChannel.invokeMethod<bool>('hasPermission');
      return hasPerm ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _controlChannel.invokeMethod<void>('requestPermission');
      // Wait for user action and check permission status
      for (int i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (await hasPermission()) return true;
      }
      return await hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> start(int sampleRate) async {
    final bool hasPerm = await hasPermission();
    if (!hasPerm) {
      final bool requested = await requestPermission();
      if (!requested) return false;
    }

    try {
      final bool? success = await _controlChannel.invokeMethod<bool>('start', {'sampleRate': sampleRate});
      if (success != true) return false;

      _actualSampleRate = sampleRate;

      await _subscription?.cancel();
      _subscription = _audioChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is List) {
            final List<double> doubleList = List<double>.from(
              event.map((e) => (e as num).toDouble()),
            );
            if (_controller.hasListener && !_controller.isClosed) {
              _controller.add(doubleList);
            }
          }
        },
        onError: (err) {
          if (_controller.hasListener && !_controller.isClosed) {
            _controller.addError(err);
          }
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _controlChannel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  @override
  int get actualSampleRate => _actualSampleRate;
}

AudioInputPort getAudioAdapter() => AudioAdapterMobile();
