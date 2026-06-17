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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SELECT INSTRUMENT",
          style: TextStyle(
            color: Colors.grey.withOpacity(0.5),
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8.0),
        
        // Scrolling list of instruments
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Chromatic Option Card
              _buildInstrumentCard(
                label: "Chromatic",
                icon: Icons.music_note,
                isSelected: selectedInstrument == null,
                onTap: onSelectChromatic,
              ),
              ...instruments.map((inst) {
                IconData icon;
                switch (inst.type) {
                  case 'guitar':
                    icon = Icons.music_video_outlined; // Guitar placeholder icon
                    break;
                  case 'bass':
                    icon = Icons.speaker_group; // Bass placeholder
                    break;
                  case 'ukulele':
                    icon = Icons.library_music_outlined; // Ukulele placeholder
                    break;
                  case 'violin':
                    icon = Icons.gesture_rounded; // Violin placeholder
                    break;
                  default:
                    icon = Icons.music_note;
                }
                return _buildInstrumentCard(
                  label: inst.name,
                  icon: icon,
                  isSelected: selectedInstrument == inst,
                  onTap: () => onSelectInstrument(inst),
                );
              }),
            ],
          ),
        ),

        // Tuning Dropdown for Selected Instrument
        if (selectedInstrument != null && selectedTuning != null) ...[
          const SizedBox(height: 12.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
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
        ],
      ],
    );
  }

  Widget _buildInstrumentCard({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.cyan.withOpacity(0.12)
                : Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isSelected
                  ? Colors.cyan.withOpacity(0.4)
                  : Colors.white.withOpacity(0.04),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16.0,
                color: isSelected ? Colors.cyanAccent : Colors.grey,
              ),
              const SizedBox(width: 8.0),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontSize: 12.0,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
