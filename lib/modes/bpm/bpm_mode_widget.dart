import 'dart:math';
import 'package:flutter/material.dart';
import 'bpm_mode.dart';
import '../../ui/app_orchestrator.dart';

/// UI widget for the BPM detection mode.
class BpmModeWidget extends StatefulWidget {
  final BpmMode mode;
  final AppOrchestrator orchestrator;

  const BpmModeWidget({
    super.key,
    required this.mode,
    required this.orchestrator,
  });

  @override
  State<BpmModeWidget> createState() => _BpmModeWidgetState();
}

class _BpmModeWidgetState extends State<BpmModeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.mode.state;
    final bool active = widget.orchestrator.isListening;
    final bool hasBpm = state.bpm > 0;

    final Color themeColor = hasBpm
        ? Color.lerp(Colors.cyanAccent, Colors.greenAccent, state.confidence)!
        : Colors.cyanAccent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 720;
        if (isWide) {
          return _buildWide(context, state, active, hasBpm, themeColor);
        } else {
          return _buildNarrow(context, state, active, hasBpm, themeColor);
        }
      },
    );
  }

  Widget _buildNarrow(BuildContext context, BpmState state, bool active,
      bool hasBpm, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          _buildBeatIndicator(state, themeColor),
          const SizedBox(height: 24),
          _buildBpmDisplay(state, hasBpm, themeColor),
          const SizedBox(height: 8),
          _buildConfidenceBar(state, themeColor),
          const SizedBox(height: 32),
          _buildTapButton(themeColor),
          const SizedBox(height: 16),
          _buildSignalLevel(state),
          const Spacer(),
          _buildStartStopButton(active),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildWide(BuildContext context, BpmState state, bool active,
      bool hasBpm, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBeatIndicator(state, themeColor),
                const SizedBox(height: 24),
                _buildBpmDisplay(state, hasBpm, themeColor),
                const SizedBox(height: 8),
                _buildConfidenceBar(state, themeColor),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTapButton(themeColor),
                const SizedBox(height: 24),
                _buildSignalLevel(state),
                const SizedBox(height: 32),
                _buildStartStopButton(active),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeatIndicator(BpmState state, Color themeColor) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final bool flash = state.isBeatFlash;
        final double outerSize = flash ? 120.0 : 90.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: outerSize,
          height: outerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: flash
                ? themeColor.withOpacity(0.25)
                : Colors.white.withOpacity(0.03),
            border: Border.all(
              color: flash ? themeColor : Colors.white.withOpacity(0.08),
              width: flash ? 2.5 : 1.5,
            ),
            boxShadow: flash
                ? [
                    BoxShadow(
                      color: themeColor.withOpacity(0.5),
                      blurRadius: 32,
                      spreadRadius: 4,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Icon(
              Icons.music_note,
              size: 32,
              color: flash ? themeColor : Colors.grey.withOpacity(0.3),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBpmDisplay(BpmState state, bool hasBpm, Color themeColor) {
    return Column(
      children: [
        Text(
          hasBpm ? state.bpm.toStringAsFixed(1) : '--',
          style: TextStyle(
            color: hasBpm ? themeColor : Colors.grey.withOpacity(0.3),
            fontSize: 80.0,
            fontWeight: FontWeight.w900,
            letterSpacing: -4,
            shadows: hasBpm
                ? [Shadow(color: themeColor.withOpacity(0.5), blurRadius: 24)]
                : [],
          ),
        ),
        Text(
          'BPM',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.6),
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hasBpm
              ? _bpmCategory(state.bpm)
              : (widget.orchestrator.isListening ? 'Listening for beat...' : 'Tap START to detect'),
          style: TextStyle(
            color: Colors.grey.withOpacity(0.45),
            fontSize: 11.0,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  String _bpmCategory(double bpm) {
    if (bpm < 60) return 'Largo / Very slow';
    if (bpm < 80) return 'Andante / Walking pace';
    if (bpm < 100) return 'Moderato / Moderate';
    if (bpm < 120) return 'Allegretto / Lively';
    if (bpm < 156) return 'Allegro / Fast';
    if (bpm < 176) return 'Vivace / Very fast';
    return 'Presto / Extremely fast';
  }

  Widget _buildConfidenceBar(BpmState state, Color themeColor) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Stability: ',
              style: TextStyle(
                color: Colors.grey.withOpacity(0.4),
                fontSize: 10.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: Container(
                width: 120,
                height: 6,
                color: Colors.white.withOpacity(0.05),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: state.confidence,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orangeAccent, themeColor],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(state.confidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: themeColor.withOpacity(0.7),
                fontSize: 10.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignalLevel(BpmState state) {
    if (!widget.orchestrator.isListening) return const SizedBox(height: 12);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mic,
          size: 12.0,
          color: state.amplitude > 0.005 ? Colors.greenAccent : Colors.grey.withOpacity(0.4),
        ),
        const SizedBox(width: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2.0),
          child: Container(
            width: 100,
            height: 4.0,
            color: Colors.white.withOpacity(0.04),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (sqrt(state.amplitude) * 3.5).clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.cyanAccent, Colors.greenAccent],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTapButton(Color themeColor) {
    return Column(
      children: [
        GestureDetector(
          onTap: widget.mode.registerTap,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  themeColor.withOpacity(0.18),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              border: Border.all(color: themeColor.withOpacity(0.4), width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, color: themeColor, size: 36),
                const SizedBox(height: 8),
                Text(
                  'TAP TEMPO',
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to manually set BPM',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.35),
            fontSize: 10.0,
          ),
        ),
      ],
    );
  }

  Widget _buildStartStopButton(bool active) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulseValue = _pulseController.value;
        return GestureDetector(
          onTap: widget.orchestrator.toggleListening,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: active
                    ? [Colors.redAccent.withOpacity(0.85), const Color(0xFFFF5252)]
                    : [Colors.cyan[600]!, Colors.cyanAccent],
              ),
              borderRadius: BorderRadius.circular(26.0),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.35 + pulseValue * 0.2),
                        blurRadius: 10 + pulseValue * 6,
                        spreadRadius: 1 + pulseValue * 2,
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(active ? Icons.mic_off : Icons.mic, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  active ? 'STOP LISTENING' : 'START LISTENING',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
