import 'package:flutter/material.dart';
import '../../domain/tuner_models.dart';

class InstrumentSelector extends StatelessWidget {
  final List<Instrument> instruments;
  final Instrument? selectedInstrument;
  final Tuning? selectedTuning;
  final Function() onSelectChromatic;
  final Function(Instrument) onSelectInstrument;
  final Function(Tuning) onSelectTuning;

  const InstrumentSelector({
    super.key,
    required this.instruments,
    required this.selectedInstrument,
    required this.selectedTuning,
    required this.onSelectChromatic,
    required this.onSelectInstrument,
    required this.onSelectTuning,
  });

  @override
  Widget build(BuildContext context) {
    final showTuningDropdown = selectedInstrument != null && selectedTuning != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TUNER PRESET",
          style: TextStyle(
            color: Colors.grey.withOpacity(0.5),
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8.0),
        
        Row(
          children: [
            // Instrument Selection Dropdown
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Instrument?>(
                    value: selectedInstrument,
                    dropdownColor: Colors.grey[900],
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    isExpanded: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                    ),
                    items: [
                      DropdownMenuItem<Instrument?>(
                        value: null,
                        child: const Row(
                          children: [
                            Icon(Icons.music_note, size: 14.0, color: Colors.cyanAccent),
                            SizedBox(width: 8.0),
                            Text("Chromatic Tuner"),
                          ],
                        ),
                      ),
                      ...instruments.map((inst) {
                        IconData icon;
                        switch (inst.type) {
                          case 'guitar':
                            icon = Icons.music_video_outlined;
                            break;
                          case 'bass':
                            icon = Icons.speaker_group;
                            break;
                          case 'ukulele':
                            icon = Icons.library_music_outlined;
                            break;
                          case 'violin':
                            icon = Icons.gesture_rounded;
                            break;
                          default:
                            icon = Icons.music_note;
                        }
                        return DropdownMenuItem<Instrument?>(
                          value: inst,
                          child: Row(
                            children: [
                              Icon(icon, size: 14.0, color: Colors.grey),
                              const SizedBox(width: 8.0),
                              Text(inst.name),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (Instrument? val) {
                      if (val == null) {
                        onSelectChromatic();
                      } else {
                        onSelectInstrument(val);
                      }
                    },
                  ),
                ),
              ),
            ),
            
            // Tuning Presets Dropdown (only visible when an instrument is active)
            if (showTuningDropdown) ...[
              const SizedBox(width: 8.0),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Tuning>(
                      value: selectedTuning,
                      dropdownColor: Colors.grey[900],
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      isExpanded: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (Tuning? newTuning) {
                        if (newTuning != null) {
                          onSelectTuning(newTuning);
                        }
                      },
                      items: selectedInstrument!.tunings.map<DropdownMenuItem<Tuning>>((Tuning t) {
                        return DropdownMenuItem<Tuning>(
                          value: t,
                          child: Text(t.name),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
