import 'dart:math';

/// Represents a musical note with target frequency and name.
class Note {
  final String name; // E.g., "C", "F#", "A"
  final int octave; // E.g., 2, 4
  final double frequency; // Standard target frequency in Hz
  final int midiNumber; // MIDI note number

  Note({
    required this.name,
    required this.octave,
    required this.frequency,
    required this.midiNumber,
  });

  String get label => '$name$octave';

  static const List<String> noteNames = [
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
  ];

  /// Generate a Note from a MIDI number.
  static Note fromMidiNumber(int midi, {double referenceFrequency = 440.0}) {
    final name = noteNames[midi % 12];
    final octave = (midi ~/ 12) - 1;
    final frequency = referenceFrequency * pow(2.0, (midi - 69) / 12.0);
    return Note(
      name: name,
      octave: octave,
      frequency: frequency,
      midiNumber: midi,
    );
  }

  /// Find the closest Note for a given frequency.
  static Note fromFrequency(double freq, {double referenceFrequency = 440.0}) {
    if (freq <= 0) return fromMidiNumber(69, referenceFrequency: referenceFrequency);
    final midiFraction = 69.0 + 12.0 * (log(freq / referenceFrequency) / log(2.0));
    return fromMidiNumber(midiFraction.round(), referenceFrequency: referenceFrequency);
  }

  /// Calculate the cents difference between a frequency and this note.
  double centsDifference(double freq, {double referenceFrequency = 440.0}) {
    if (freq <= 0) return 0;
    // Cents = 1200 * log2(f / f_target)
    return 1200.0 * (log(freq / frequency) / log(2.0));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          runtimeType == other.runtimeType &&
          midiNumber == other.midiNumber;

  @override
  int get hashCode => midiNumber.hashCode;

  @override
  String toString() => label;
}

/// Represents a specific string on an instrument.
class InstrumentString {
  final int index; // 1-indexed from high string to low string or vice-versa
  final Note note;
  final String label; // Optional custom name, e.g. "1st String"

  InstrumentString({
    required this.index,
    required this.note,
    this.label = '',
  });
}

/// Represents a specific tuning definition for an instrument.
class Tuning {
  final String name; // E.g., "Standard", "Drop D"
  final List<InstrumentString> strings; // Ordered list of strings

  Tuning({
    required this.name,
    required this.strings,
  });

  /// Helper to get strings in display order (usually high-to-low or low-to-high)
  List<InstrumentString> get displayStrings => strings;
}

/// Represents a musical instrument with multiple presets of tunings.
class Instrument {
  final String name;
  final String type; // E.g., "Guitar", "Bass", "Ukulele", "Violin"
  final List<Tuning> tunings;
  final String iconPath; // For visual assets/icons

  Instrument({
    required this.name,
    required this.type,
    required this.tunings,
    this.iconPath = '',
  });

  Tuning get defaultTuning => tunings.first;

  static List<Instrument> get presets => [
        Instrument(
          name: "Guitar",
          type: "guitar",
          iconPath: "guitar",
          tunings: [
            Tuning(
              name: "Standard (EADGBE)",
              strings: [
                InstrumentString(index: 1, note: Note.fromMidiNumber(64)), // E4 (329.63 Hz)
                InstrumentString(index: 2, note: Note.fromMidiNumber(59)), // B3 (246.94 Hz)
                InstrumentString(index: 3, note: Note.fromMidiNumber(55)), // G3 (196.00 Hz)
                InstrumentString(index: 4, note: Note.fromMidiNumber(50)), // D3 (146.83 Hz)
                InstrumentString(index: 5, note: Note.fromMidiNumber(45)), // A2 (110.00 Hz)
                InstrumentString(index: 6, note: Note.fromMidiNumber(40)), // E2 (82.41 Hz)
              ],
            ),
            Tuning(
              name: "Drop D",
              strings: [
                InstrumentString(index: 1, note: Note.fromMidiNumber(64)), // E4
                InstrumentString(index: 2, note: Note.fromMidiNumber(59)), // B3
                InstrumentString(index: 3, note: Note.fromMidiNumber(55)), // G3
                InstrumentString(index: 4, note: Note.fromMidiNumber(50)), // D3
                InstrumentString(index: 5, note: Note.fromMidiNumber(45)), // A2
                InstrumentString(index: 6, note: Note.fromMidiNumber(38)), // D2 (73.42 Hz)
              ],
            ),
            Tuning(
              name: "Half-Step Down",
              strings: [
                InstrumentString(index: 1, note: Note.fromMidiNumber(63)), // Eb4
                InstrumentString(index: 2, note: Note.fromMidiNumber(58)), // Bb3
                InstrumentString(index: 3, note: Note.fromMidiNumber(54)), // Gb3
                InstrumentString(index: 4, note: Note.fromMidiNumber(49)), // Db3
                InstrumentString(index: 5, note: Note.fromMidiNumber(44)), // Ab2
                InstrumentString(index: 6, note: Note.fromMidiNumber(39)), // Eb2
              ],
            ),
            Tuning(
              name: "DADGAD",
              strings: [
                InstrumentString(index: 1, note: Note.fromMidiNumber(62)), // D4
                InstrumentString(index: 2, note: Note.fromMidiNumber(57)), // A3
                InstrumentString(index: 3, note: Note.fromMidiNumber(55)), // G3
                InstrumentString(index: 4, note: Note.fromMidiNumber(50)), // D3
                InstrumentString(index: 5, note: Note.fromMidiNumber(45)), // A2
                InstrumentString(index: 6, note: Note.fromMidiNumber(38)), // D2
              ],
            ),
          ],
        ),
        Instrument(
          name: "Bass Guitar",
          type: "bass",
          iconPath: "bass",
          tunings: [
            Tuning(
              name: "Standard 4-String (EADG)",
              strings: [
                InstrumentString(index: 1, note: Note.fromMidiNumber(43)), // G2 (98.00 Hz)
                InstrumentString(index: 2, note: Note.fromMidiNumber(38)), // D2 (73.42 Hz)
                InstrumentString(index: 3, note: Note.fromMidiNumber(33)), // A1 (55.00 Hz)
                InstrumentString(index: 4, note: Note.fromMidiNumber(28)), // E1 (41.20 Hz)
              ],
            ),
            Tuning(
              name: "Standard 5-String (BEADG)",
              strings: [
                InstrumentString(index: 1, note: Note.fromMidiNumber(43)), // G2
                InstrumentString(index: 2, note: Note.fromMidiNumber(38)), // D2
                InstrumentString(index: 3, note: Note.fromMidiNumber(33)), // A1
                InstrumentString(index: 4, note: Note.fromMidiNumber(28)), // E1
                InstrumentString(index: 5, note: Note.fromMidiNumber(23)), // B0 (30.87 Hz)
              ],
            ),
          ],
        ),
        Instrument(
          name: "Ukulele",
          type: "ukulele",
          iconPath: "ukulele",
          tunings: [
            Tuning(
              name: "Standard (GCEA)",
              strings: [
                InstrumentString(index: 1, note: Note.fromMidiNumber(69)), // A4 (440.00 Hz)
                InstrumentString(index: 2, note: Note.fromMidiNumber(64)), // E4 (329.63 Hz)
                InstrumentString(index: 3, note: Note.fromMidiNumber(60)), // C4 (261.63 Hz)
                InstrumentString(index: 4, note: Note.fromMidiNumber(67)), // G4 (392.00 Hz)
              ],
            ),
          ],
        ),
        Instrument(
          name: "Violin",
          type: "violin",
          iconPath: "violin",
          tunings: [
            Tuning(
              name: "Standard (GDAE)",
              strings: [
                InstrumentString(index: 1, note: Note.fromMidiNumber(76)), // E5 (659.25 Hz)
                InstrumentString(index: 2, note: Note.fromMidiNumber(69)), // A4 (440.00 Hz)
                InstrumentString(index: 3, note: Note.fromMidiNumber(62)), // D4 (293.66 Hz)
                InstrumentString(index: 4, note: Note.fromMidiNumber(55)), // G3 (196.00 Hz)
              ],
            ),
          ],
        ),
      ];
}

/// Historical audio data point for the spectrogram waterfall display.
class HistoryPoint {
  final double frequency;
  final double amplitude;
  final DateTime timestamp;

  HistoryPoint({
    required this.frequency,
    required this.amplitude,
    required this.timestamp,
  });
}

/// Represents the current measurement from the pitch detector.
class TuningState {
  final double frequency; // Detected fundamental frequency in Hz (0 if no signal)
  final double centsOffset; // Cents difference (-50 to +50)
  final Note closestNote; // Note closest to the detected frequency
  final InstrumentString? closestString; // The string matching this note if using auto-detect instrument tuning
  final double amplitude; // Signal volume amplitude (normalized [0, 1])
  final bool hasSignal; // Whether audio amplitude exceeds threshold

  TuningState({
    required this.frequency,
    required this.centsOffset,
    required this.closestNote,
    this.closestString,
    required this.amplitude,
    required this.hasSignal,
  });

  /// Check if the note is "locked" in tune within ±3 cents
  bool get isLocked => hasSignal && centsOffset.abs() <= 3.0;

  factory TuningState.idle() {
    return TuningState(
      frequency: 0,
      centsOffset: 0,
      closestNote: Note.fromMidiNumber(69),
      amplitude: 0,
      hasSignal: false,
    );
  }
}
