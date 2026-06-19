import 'package:flutter/material.dart';
import '../app_orchestrator.dart';
import '../../modes/tuner/tuner_mode.dart';
import '../../modes/tuner/tuner_mode_widget.dart';
import '../../modes/bpm/bpm_mode.dart';
import '../../modes/bpm/bpm_mode_widget.dart';
import '../../modes/metronome/metronome_mode.dart';
import '../../modes/metronome/metronome_mode_widget.dart';
import '../../modes/tone_generator/tone_generator_mode.dart';
import '../../modes/tone_generator/tone_generator_mode_widget.dart';
import '../../domain/app_mode.dart';

/// Root screen that hosts the mode selector and renders the active mode's UI.
class RootScreen extends StatelessWidget {
  final AppOrchestrator orchestrator;

  const RootScreen({super.key, required this.orchestrator});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: orchestrator,
      builder: (context, _) {
        final currentMode = orchestrator.currentMode;

        return Scaffold(
          backgroundColor: const Color(0xFF0D0F13),
          body: Stack(
            children: [
              // Active mode UI
              SafeArea(
                child: Column(
                  children: [
                    _ModeSelector(orchestrator: orchestrator),
                    Expanded(
                      child: _buildModeUI(context, currentMode),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeUI(BuildContext context, AppMode? mode) {
    if (mode == null) return const SizedBox();

    switch (mode.id) {
      case 'tuner':
        return TunerModeWidget(
          mode: mode as TunerMode,
          orchestrator: orchestrator,
        );
      case 'bpm':
        return BpmModeWidget(
          mode: mode as BpmMode,
          orchestrator: orchestrator,
        );
      case 'metronome':
        return MetronomeModeWidget(
          mode: mode as MetronomeMode,
          orchestrator: orchestrator,
        );
      case 'tone_generator':
        return ToneGeneratorModeWidget(
          mode: mode as ToneGeneratorMode,
          orchestrator: orchestrator,
        );
      default:
        return Center(
          child: Text(
            'Unknown mode: ${mode.id}',
            style: const TextStyle(color: Colors.white),
          ),
        );
    }
  }
}

/// Horizontal mode selector dropdown menu.
class _ModeSelector extends StatelessWidget {
  final AppOrchestrator orchestrator;

  const _ModeSelector({required this.orchestrator});

  @override
  Widget build(BuildContext context) {
    final currentMode = orchestrator.currentMode;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // App title/logo
          Text(
            'TUNING VIBES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              shadows: [
                Shadow(
                  color: Colors.cyanAccent.withOpacity(0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Mode Dropdown Selection Menu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentMode?.id,
                onChanged: (newId) {
                  if (newId != null) {
                    orchestrator.selectMode(newId);
                  }
                },
                dropdownColor: const Color(0xFF13161C),
                borderRadius: BorderRadius.circular(16.0),
                icon: const Padding(
                  padding: EdgeInsets.only(left: 6.0),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.cyanAccent,
                    size: 16.0,
                  ),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
                selectedItemBuilder: (BuildContext context) {
                  return orchestrator.modes.map((mode) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mode.icon,
                          size: 13.0,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          mode.displayName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
                items: orchestrator.modes.map((mode) {
                  final bool isSelected = currentMode?.id == mode.id;
                  return DropdownMenuItem<String>(
                    value: mode.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mode.icon,
                          size: 13.0,
                          color: isSelected ? Colors.cyanAccent : Colors.grey,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          mode.displayName.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.8),
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
