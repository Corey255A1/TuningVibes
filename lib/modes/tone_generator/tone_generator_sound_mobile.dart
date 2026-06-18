import 'package:flutter/services.dart';

/// Mobile implementation: forwards calls to com.tuningvibes/tone_out platform channel.
/// Falls back to silent no-op if unavailable.
const _channel = MethodChannel('com.tuningvibes/tone_out');

void startImpl(double frequency, String type, double volume) {
  _channel.invokeMethod('start', {
    'frequency': frequency,
    'type': type,
    'volume': volume,
  }).catchError((_) {
    // Platform channel not available - silent fallback
  });
}

void setFrequencyImpl(double frequency) {
  _channel.invokeMethod('setFrequency', {
    'frequency': frequency,
  }).catchError((_) {
    // Silent fallback
  });
}

void setVolumeImpl(double volume) {
  _channel.invokeMethod('setVolume', {
    'volume': volume,
  }).catchError((_) {
    // Silent fallback
  });
}

void setTypeImpl(String type) {
  _channel.invokeMethod('setType', {
    'type': type,
  }).catchError((_) {
    // Silent fallback
  });
}

void stopImpl() {
  _channel.invokeMethod('stop').catchError((_) {
    // Silent fallback
  });
}
