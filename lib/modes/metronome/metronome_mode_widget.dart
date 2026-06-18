import 'dart:math';
import 'package:flutter/material.dart';
import 'metronome_mode.dart';
import '../../ui/app_orchestrator.dart';

/// UI widget for the Metronome mode.
class MetronomeModeWidget extends StatefulWidget {
  final MetronomeMode mode;
  final AppOrchestrator orchestrator;

  const MetronomeModeWidget({
    super.key,
    required this.mode,
    required this.orchestrator,
  });

  @override
  State<MetronomeModeWidget> createState() => _MetronomeModeWidgetState();
}

class _MetronomeModeWidgetState extends State<MetronomeModeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pendulumController;

  @override
  void initState() {
    super.initState();
    _pendulumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _pendulumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.mode.state;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 720;
        if (isWide) {
          return _buildWide(context, state);
        } else {
          return _buildNarrow(context, state);
        }
      },
    );
  }

  Widget _buildNarrow(BuildContext context, MetronomeState state) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildBeatGrid(state),
            const SizedBox(height: 24),
            _buildBpmSection(state),
            const SizedBox(height: 20),
            _buildTimeSignatureSelector(state),
            const SizedBox(height: 16),
            _buildSubdivisionSelector(state),
            const SizedBox(height: 24),
            _buildTapTempoButton(),
            const SizedBox(height: 20),
            _buildPlayButton(state),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWide(BuildContext context, MetronomeState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: beat grid + BPM
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBeatGrid(state),
                const SizedBox(height: 28),
                _buildBpmSection(state),
              ],
            ),
          ),
          const SizedBox(width: 40),
          // Right: controls
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeSignatureSelector(state),
                const SizedBox(height: 16),
                _buildSubdivisionSelector(state),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTapTempoButton(),
                    const SizedBox(width: 16),
                    _buildPlayButton(state),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Animated grid of beat circles — one per beat in the measure.
  Widget _buildBeatGrid(MetronomeState state) {
    final int total = state.timeSignature.beatsPerMeasure;
    final int active = state.currentBeat; // 1-indexed

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: List.generate(total, (i) {
        final int beatNum = i + 1;
        final bool isActive = state.isPlaying && beatNum == active;
        final bool isDownbeat = beatNum == 1;
        final bool flash = isActive && state.isTickFlash;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: flash ? 54 : 46,
          height: flash ? 54 : 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: flash
                ? (isDownbeat
                    ? Colors.cyanAccent.withOpacity(0.35)
                    : Colors.white.withOpacity(0.15))
                : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: flash
                  ? (isDownbeat ? Colors.cyanAccent : Colors.white.withOpacity(0.6))
                  : (isDownbeat
                      ? Colors.cyanAccent.withOpacity(0.3)
                      : Colors.white.withOpacity(0.08)),
              width: flash ? 2.0 : 1.5,
            ),
            boxShadow: flash
                ? [
                    BoxShadow(
                      color: isDownbeat
                          ? Colors.cyanAccent.withOpacity(0.5)
                          : Colors.white.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              '$beatNum',
              style: TextStyle(
                color: flash
                    ? (isDownbeat ? Colors.cyanAccent : Colors.white)
                    : Colors.grey.withOpacity(0.3),
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBpmSection(MetronomeState state) {
    return Column(
      children: [
        // BPM number display
        Text(
          state.bpm.toStringAsFixed(0),
          style: TextStyle(
            color: Colors.white,
            fontSize: 80.0,
            fontWeight: FontWeight.w900,
            letterSpacing: -4,
            shadows: [
              Shadow(
                color: Colors.cyanAccent.withOpacity(0.3),
                blurRadius: 20,
              )
            ],
          ),
        ),
        Text(
          'BPM',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.5),
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: 16),
        // BPM Slider
        Row(
          children: [
            _bpmIncrementButton(-5),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.cyanAccent,
                  inactiveTrackColor: Colors.white.withOpacity(0.08),
                  thumbColor: Colors.cyanAccent,
                  overlayColor: Colors.cyanAccent.withOpacity(0.12),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  trackHeight: 3.0,
                ),
                child: Slider(
                  value: state.bpm.clamp(20.0, 240.0),
                  min: 20,
                  max: 240,
                  onChanged: widget.mode.setBpm,
                ),
              ),
            ),
            _bpmIncrementButton(5),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('20', style: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 9.0)),
            Text('120', style: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 9.0)),
            Text('240', style: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 9.0)),
          ],
        ),
      ],
    );
  }

  Widget _bpmIncrementButton(int delta) {
    return GestureDetector(
      onTap: () => widget.mode.setBpm(widget.mode.state.bpm + delta),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Center(
          child: Text(
            delta > 0 ? '+$delta' : '$delta',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSignatureSelector(MetronomeState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIME SIGNATURE',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.5),
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TimeSignature.presets.map((sig) {
            final bool selected =
                sig.beatsPerMeasure == state.timeSignature.beatsPerMeasure &&
                    sig.beatUnit == state.timeSignature.beatUnit;
            return GestureDetector(
              onTap: () => widget.mode.setTimeSignature(sig),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.cyanAccent.withOpacity(0.15)
                      : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                    color: selected
                        ? Colors.cyanAccent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Text(
                  sig.label,
                  style: TextStyle(
                    color: selected ? Colors.cyanAccent : Colors.grey,
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubdivisionSelector(MetronomeState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUBDIVISIONS',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.5),
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SubdivisionMode.values.map((mode) {
            final bool selected = state.subdivision == mode;
            return GestureDetector(
              onTap: () => widget.mode.setSubdivision(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.purpleAccent.withOpacity(0.15)
                      : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                    color: selected
                        ? Colors.purpleAccent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Text(
                  mode.label,
                  style: TextStyle(
                    color: selected ? Colors.purpleAccent : Colors.grey,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTapTempoButton() {
    return GestureDetector(
      onTap: widget.mode.registerTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, color: Colors.grey.withOpacity(0.7), size: 18),
            const SizedBox(width: 8),
            Text(
              'TAP TEMPO',
              style: TextStyle(
                color: Colors.grey.withOpacity(0.7),
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton(MetronomeState state) {
    final bool playing = state.isPlaying;
    return GestureDetector(
      onTap: widget.mode.togglePlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 14.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: playing
                ? [Colors.redAccent.withOpacity(0.85), const Color(0xFFFF5252)]
                : [Colors.cyan[700]!, Colors.cyanAccent],
          ),
          borderRadius: BorderRadius.circular(14.0),
          boxShadow: [
            BoxShadow(
              color: playing
                  ? Colors.redAccent.withOpacity(0.4)
                  : Colors.cyanAccent.withOpacity(0.3),
              blurRadius: 14,
              spreadRadius: 1,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              playing ? 'STOP' : 'START',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
