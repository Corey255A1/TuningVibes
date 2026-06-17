import 'dart:math';
import 'package:flutter/material.dart';
import '../tuner_view_model.dart';
import '../widgets/waveform_painter.dart';
import '../widgets/needle_painter.dart';
import '../widgets/waterfall_painter.dart';
import '../widgets/instrument_pegs.dart';
import '../widgets/instrument_selector.dart';

class TunerScreen extends StatefulWidget {
  final TunerViewModel viewModel;

  const TunerScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Pulse animation controller for the mic listen button and glowing elements
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
          listenable: widget.viewModel,
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
                    "A4 = ${widget.viewModel.referencePitch.toStringAsFixed(1)} Hz",
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 24.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: widget.viewModel.referencePitch,
                    min: 432.0,
                    max: 446.0,
                    divisions: 14,
                    activeColor: Colors.cyanAccent,
                    inactiveColor: Colors.grey[800],
                    label: widget.viewModel.referencePitch.round().toString(),
                    onChanged: (val) {
                      widget.viewModel.referencePitch = val;
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
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final state = widget.viewModel.state;
        final hasSignal = state.hasSignal;
        final isLocked = state.isLocked;

        // Dynamic theme color based on tuning state
        Color glowColor = Colors.cyanAccent;
        if (hasSignal) {
          glowColor = isLocked ? Colors.greenAccent : (state.centsOffset > 0 ? Colors.redAccent : Colors.orangeAccent);
        }

        return Scaffold(
          backgroundColor: const Color(0xFF08090B), // Darker outer page background
          body: Center(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0F13), // Standard card background
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
              // 1. Organic real-time waveform running in the background
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15,
                  child: Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      height: 250,
                      child: RealtimeWaveform(
                        samples: widget.viewModel.waveformSamples,
                        color: glowColor,
                        hasSignal: hasSignal,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Main content container
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 8.0),
                      // Top header bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TUNING VIBES",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.cyanAccent.withOpacity(0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "HIGH PRECISION AUDIO ENGINE",
                                style: TextStyle(
                                  color: Colors.cyanAccent.withOpacity(0.6),
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          
                          // Calibration button
                          GestureDetector(
                            onTap: () => _showCalibrationDialog(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
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
                                    "A4 = ${widget.viewModel.referencePitch.round()}Hz",
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
                      ),
                      
                      const SizedBox(height: 12.0),

                      // Instrument selection bar
                      InstrumentSelector(
                        instruments: widget.viewModel.instruments,
                        selectedInstrument: widget.viewModel.selectedInstrument,
                        selectedTuning: widget.viewModel.selectedTuning,
                        onSelectChromatic: widget.viewModel.selectChromaticMode,
                        onSelectInstrument: widget.viewModel.selectInstrument,
                        onSelectTuning: widget.viewModel.selectTuning,
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              const SizedBox(height: 10.0),
                              
                              // The needle gauge display
                              TunerGauge(
                                cents: state.centsOffset,
                                hasSignal: hasSignal,
                                isLocked: isLocked,
                                themeColor: glowColor,
                              ),
                              
                              // Note name display with glow
                              Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 100),
                                        style: TextStyle(
                                          color: hasSignal ? glowColor : Colors.grey[700],
                                          fontSize: 72.0,
                                          fontWeight: FontWeight.w900,
                                          shadows: hasSignal
                                              ? [
                                                  Shadow(
                                                    color: glowColor.withOpacity(0.6),
                                                    blurRadius: 24,
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Text(state.closestNote.name),
                                      ),
                                      const SizedBox(width: 2.0),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12.0),
                                        child: Text(
                                          hasSignal ? state.closestNote.octave.toString() : "",
                                          style: TextStyle(
                                            color: hasSignal ? glowColor.withOpacity(0.7) : Colors.grey[800],
                                            fontSize: 24.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Frequency and Cent readout
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
                                            widget.viewModel.isListening 
                                                ? "Pluck a string..." 
                                                : "Tap start to tune",
                                            style: TextStyle(
                                              color: Colors.grey.withOpacity(0.5),
                                              fontSize: 12.0,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                  ),
                                  
                                  // Input Level / Audio Activity Indicator
                                  if (widget.viewModel.isListening) ...[
                                    const SizedBox(height: 8.0),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.mic,
                                          size: 11.0,
                                          color: state.amplitude > 0.005
                                              ? Colors.greenAccent
                                              : Colors.grey.withOpacity(0.5),
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
                                        // Visual Level Meter
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
                                ],
                              ),
                              
                              const SizedBox(height: 12.0),

                              // Interactive pegboard headstock
                              if (widget.viewModel.selectedInstrument != null && 
                                  widget.viewModel.selectedTuning != null) ...[
                                InstrumentPegs(
                                  tuning: widget.viewModel.selectedTuning!,
                                  activeString: state.closestString,
                                  selectedString: widget.viewModel.selectedString,
                                  onSelectString: widget.viewModel.selectString,
                                  hasSignal: hasSignal,
                                  isLocked: isLocked,
                                ),
                              ] else ...[
                                // Chromatic mode helper graphic
                                Container(
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
                                ),
                              ],
                              
                              const SizedBox(height: 20.0),
                            ],
                          ),
                        ),
                      ),

                      // Spectrogram history graph
                      SpectrogramWaterfall(
                        history: widget.viewModel.frequencyHistory,
                        referencePitch: widget.viewModel.referencePitch,
                      ),

                      // 3. Audio toggle button
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulseValue = _pulseController.value;
                            final bool active = widget.viewModel.isListening;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: GestureDetector(
                                onTap: widget.viewModel.toggleListening,
                                child: Container(
                                  height: 54,
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: active
                                          ? [Colors.redAccent.withOpacity(0.85), const Color(0xFFFF5252)]
                                          : [Colors.cyan[600]!, Colors.cyanAccent],
                                    ),
                                    borderRadius: BorderRadius.circular(28.0),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        active ? Icons.mic_off : Icons.mic,
                                        color: Colors.white,
                                        size: 20.0,
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}
