import 'dart:js_interop';

@JS('metronome.playClick')
external void _jsPlayClick(int type);

void playClickImpl(int type) {
  try {
    _jsPlayClick(type);
  } catch (_) {}
}
