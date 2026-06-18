import 'package:flutter/material.dart';
import '../app_orchestrator.dart';
import '../../modes/tuner/tuner_mode.dart';
import '../../modes/tuner/tuner_mode_widget.dart';
import '../../modes/bpm/bpm_mode.dart';
import '../../modes/bpm/bpm_mode_widget.dart';
import '../../modes/metronome/metronome_mode.dart';
import '../../modes/metronome/metronome_mode_widget.dart';
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

/// Horizontal mode selector tab bar.
class _ModeSelector extends StatelessWidget {
  final AppOrchestrator orchestrator;

  const _ModeSelector({required this.orchestrator});

  @override
  Widget build(BuildContext context) {
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
          // Mode tabs
          ...orchestrator.modes.map((mode) => _ModeTab(
                mode: mode,
                isSelected: orchestrator.currentMode?.id == mode.id,
                onTap: () => orchestrator.selectMode(mode.id),
              )),
        ],
      ),
    );
  }
}

/// Individual mode tab chip in the selector bar.
class _ModeTab extends StatelessWidget {
  final AppMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(left: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withOpacity(0.15)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected
                ? Colors.cyanAccent.withOpacity(0.6)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode.icon,
              size: 13.0,
              color: isSelected ? Colors.cyanAccent : Colors.grey,
            ),
            const SizedBox(width: 5.0),
            Text(
              mode.displayName.toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.cyanAccent : Colors.grey,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
