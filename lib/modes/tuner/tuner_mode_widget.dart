import 'dart:math';
import 'package:flutter/material.dart';
import 'tuner_mode.dart';
import '../../ui/app_orchestrator.dart';
import '../../ui/widgets/waveform_painter.dart';
import '../../ui/widgets/needle_painter.dart';
import '../../ui/widgets/waterfall_painter.dart';
import '../../ui/widgets/instrument_pegs.dart';
import '../../ui/widgets/instrument_selector.dart';
import '../../domain/tuner_models.dart';

/// The Tuner mode's full UI, adapted from the original TunerScreen.
/// Receives state from [TunerMode] and delegates interactions back to it.
class TunerModeWidget extends StatefulWidget {
  final TunerMode mode;
  final AppOrchestrator orchestrator;

  const TunerModeWidget({
    super.key,
    required this.mode,
    required this.orchestrator,
  });

  @override
  State<TunerModeWidget> createState() => _TunerModeWidgetState();
}

class _TunerModeWidgetState extends State<TunerModeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showCalibrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return ListenableBuilder(
          listenable: widget.orchestrator,
          builder: (context, _) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              title: const Text(
                "Reference Pitch Calibration",
                style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "A4 = ${widget.mode.referencePitch.toStringAsFixed(1)} Hz",
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 24.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: widget.mode.referencePitch,
                    min: 432.0,
                    max: 446.0,
                    divisions: 14,
                    activeColor: Colors.cyanAccent,
                    inactiveColor: Colors.grey[800],
                    label: widget.mode.referencePitch.round().toString(),
                    onChanged: (val) {
                      widget.mode.referencePitch = val;
                    },
                  ),
                  const Text(
                    "Standard orchestral tuning is 440 Hz.\n432 Hz is popular for alternative tuning methods.",
                    style: TextStyle(color: Colors.grey, fontSize: 10.0),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CLOSE", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeState = widget.mode.state;
    final tuningState = modeState.tuningState;
    final hasSignal = tuningState.hasSignal;
    final isLocked = tuningState.isLocked;

    Color glowColor = Colors.cyanAccent;
    if (hasSignal) {
      glowColor = isLocked
          ? Colors.greenAccent
          : (tuningState.centsOffset > 0 ? Colors.redAccent : Colors.orangeAccent);
    }

    return Stack(
      children: [
        // Background waveform
        Positioned.fill(
          child: Opacity(
            opacity: 0.12,
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                height: 280,
                child: RealtimeWaveform(
                  samples: modeState.waveformSamples,
                  color: glowColor,
                  hasSignal: hasSignal,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 720;
              if (isWide) {
                return _buildLandscapeLayout(context, tuningState, hasSignal, isLocked, glowColor);
              } else {
                return _buildPortraitLayout(context, tuningState, hasSignal, isLocked, glowColor);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    TuningState state,
    bool hasSignal,
    bool isLocked,
    Color glowColor,
  ) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          children: [
            const SizedBox(height: 4.0),
            _buildCalibrationRow(context),
            const SizedBox(height: 8.0),
            _buildInstrumentSelector(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 10.0),
                    _buildGauge(state, hasSignal, isLocked, glowColor),
                    _buildNoteReadout(state, hasSignal, glowColor),
                    _buildSignalLevel(state),
                    const SizedBox(height: 16.0),
                    _buildPegboard(state, hasSignal, isLocked, glowColor),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
            _buildWaterfall(),
            _buildStartStopButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    TuningState state,
    bool hasSignal,
    bool isLocked,
    Color glowColor,
  ) {
    return Column(
      children: [
        const SizedBox(height: 4.0),
        _buildCalibrationRow(context),
        const SizedBox(height: 8.0),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 180,
                                child: _buildGauge(state, hasSignal, isLocked, glowColor),
                              ),
                              _buildNoteReadout(state, hasSignal, glowColor),
                              _buildSignalLevel(state),
                              const SizedBox(height: 10.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildStartStopButton(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Container(
                  width: 1.0,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInstrumentSelector(),
                    const SizedBox(height: 12.0),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              children: [
                                _buildPegboard(state, hasSignal, isLocked, glowColor),
                                const SizedBox(height: 8.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    _buildWaterfall(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => _showCalibrationDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 12.0, color: Colors.cyanAccent),
                const SizedBox(width: 4.0),
                Text(
                  "A4 = ${widget.mode.referencePitch.round()}Hz",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstrumentSelector() {
    return InstrumentSelector(
      instruments: widget.mode.instruments,
      selectedInstrument: widget.mode.selectedInstrument,
      selectedTuning: widget.mode.selectedTuning,
      onSelectChromatic: widget.mode.selectChromaticMode,
      onSelectInstrument: widget.mode.selectInstrument,
      onSelectTuning: widget.mode.selectTuning,
    );
  }

  Widget _buildGauge(TuningState state, bool hasSignal, bool isLocked, Color glowColor) {
    return TunerGauge(
      cents: state.centsOffset,
      hasSignal: hasSignal,
      isLocked: isLocked,
      themeColor: glowColor,
    );
  }

  Widget _buildNoteReadout(TuningState state, bool hasSignal, Color glowColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 100),
              style: TextStyle(
                color: hasSignal ? glowColor : Colors.grey[700],
                fontSize: 64.0,
                fontWeight: FontWeight.w900,
                shadows: hasSignal
                    ? [Shadow(color: glowColor.withOpacity(0.6), blurRadius: 24)]
                    : [],
              ),
              child: Text(state.closestNote.name),
            ),
            const SizedBox(width: 2.0),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                hasSignal ? state.closestNote.octave.toString() : "",
                style: TextStyle(
                  color: hasSignal ? glowColor.withOpacity(0.7) : Colors.grey[800],
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 36,
          child: hasSignal
              ? Column(
                  children: [
                    Text(
                      "${state.frequency.toStringAsFixed(2)} Hz",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      state.centsOffset.abs() < 1.0
                          ? "In Tune"
                          : "${state.centsOffset > 0 ? '+' : ''}${state.centsOffset.toStringAsFixed(1)} Cents",
                      style: TextStyle(
                        color: glowColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : Text(
                  widget.orchestrator.isListening
                      ? "Pluck a string..."
                      : "Tap start to tune",
                  style: TextStyle(
                    color: Colors.grey.withOpacity(0.5),
                    fontSize: 12.0,
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSignalLevel(TuningState state) {
    if (!widget.orchestrator.isListening) return const SizedBox(height: 12.0);
    return Column(
      children: [
        const SizedBox(height: 8.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic,
              size: 11.0,
              color: state.amplitude > 0.005 ? Colors.greenAccent : Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(width: 4.0),
            Text(
              "Signal Level: ",
              style: TextStyle(
                color: Colors.grey.withOpacity(0.4),
                fontSize: 9.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(2.0),
              child: Container(
                width: 80.0,
                height: 4.0,
                color: Colors.white.withOpacity(0.04),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (sqrt(state.amplitude) * 3.5).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyanAccent,
                          state.amplitude > 0.08 ? Colors.greenAccent : Colors.cyanAccent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPegboard(TuningState state, bool hasSignal, bool isLocked, Color glowColor) {
    if (widget.mode.selectedInstrument != null && widget.mode.selectedTuning != null) {
      return InstrumentPegs(
        tuning: widget.mode.selectedTuning!,
        activeString: state.closestString,
        selectedString: widget.mode.selectedString,
        onSelectString: widget.mode.selectString,
        hasSignal: hasSignal,
        isLocked: isLocked,
      );
    } else {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.01),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Text(
          "Chromatic Mode\nDetects any note in the scale",
          style: TextStyle(
            color: Colors.grey.withOpacity(0.5),
            fontSize: 11.0,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
  }

  Widget _buildWaterfall() {
    return SpectrogramWaterfall(
      history: widget.mode.state.frequencyHistory,
      referencePitch: widget.mode.referencePitch,
    );
  }

  Widget _buildStartStopButton() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseValue = _pulseController.value;
          final bool active = widget.orchestrator.isListening;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: GestureDetector(
              onTap: widget.orchestrator.toggleListening,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                            color: Colors.redAccent.withOpacity(0.4 + (pulseValue * 0.2)),
                            blurRadius: 10.0 + (pulseValue * 6.0),
                            spreadRadius: 1.0 + (pulseValue * 2.0),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 18.0,
                    ),
                    const SizedBox(width: 10.0),
                    Text(
                      active ? "STOP TUNER" : "START TUNER",
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
            ),
          );
        },
      ),
    );
  }
}
