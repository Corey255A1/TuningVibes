import 'dart:js_interop';

@JS('toneGenerator.start')
external void _jsStart(double frequency, JSString type, double volume);

@JS('toneGenerator.setFrequency')
external void _jsSetFrequency(double frequency);

@JS('toneGenerator.setVolume')
external void _jsSetVolume(double volume);

@JS('toneGenerator.setType')
external void _jsSetType(JSString type);

@JS('toneGenerator.stop')
external void _jsStop();

void startImpl(double frequency, String type, double volume) {
  try {
    _jsStart(frequency, type.toJS, volume);
  } catch (_) {}
}

void setFrequencyImpl(double frequency) {
  try {
    _jsSetFrequency(frequency);
  } catch (_) {}
}

void setVolumeImpl(double volume) {
  try {
    _jsSetVolume(volume);
  } catch (_) {}
}

void setTypeImpl(String type) {
  try {
    _jsSetType(type.toJS);
  } catch (_) {}
}

void stopImpl() {
  try {
    _jsStop();
  } catch (_) {}
}
