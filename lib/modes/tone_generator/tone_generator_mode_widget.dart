import 'dart:math';
import 'package:flutter/material.dart';
import 'tone_generator_mode.dart';
import '../../ui/app_orchestrator.dart';
import '../../domain/tuner_models.dart';

/// UI widget for the Tone Generator mode.
class ToneGeneratorModeWidget extends StatefulWidget {
  final ToneGeneratorMode mode;
  final AppOrchestrator orchestrator;

  const ToneGeneratorModeWidget({
    super.key,
    required this.mode,
    required this.orchestrator,
  });

  @override
  State<ToneGeneratorModeWidget> createState() => _ToneGeneratorModeWidgetState();
}

class _ToneGeneratorModeWidgetState extends State<ToneGeneratorModeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  double _wavePhase = 0.0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _waveController.addListener(() {
      setState(() {
        _wavePhase = _waveController.value * 2 * pi;
      });
    });

    final state = widget.mode.state;
    if (state.isPlaying) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ToneGeneratorModeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = widget.mode.state;
    if (state.isPlaying && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!state.isPlaying && _waveController.isAnimating) {
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  // Helper for logarithmic slider mapping [20Hz, 4000Hz] <-> [0.0, 1.0]
  double _freqToSlider(double freq) {
    final double clamped = freq.clamp(20.0, 4000.0);
    return log(clamped / 20.0) / log(200.0);
  }

  double _sliderToFreq(double val) {
    return 20.0 * pow(200.0, val);
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

  Widget _buildNarrow(BuildContext context, ToneGeneratorState state) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildVisualizerCard(state),
            const SizedBox(height: 20),
            _buildNoteSelectorCard(state),
            const SizedBox(height: 20),
            _buildWaveformAndVolumeCard(state),
            const SizedBox(height: 28),
            _buildPlayButton(state),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildWide(BuildContext context, ToneGeneratorState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left column: Visualizer and Play Button
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildVisualizerCard(state),
                const SizedBox(height: 28),
                _buildPlayButton(state),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Right column: Note Tuning and Sound settings
          Expanded(
            flex: 7,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildNoteSelectorCard(state),
                  const SizedBox(height: 20),
                  _buildWaveformAndVolumeCard(state),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Large card containing frequency, note names, cents difference, and the wave painter.
  Widget _buildVisualizerCard(ToneGeneratorState state) {
    final note = state.note;
    final centsStr = (state.centsOffset >= 0 ? '+' : '') + state.centsOffset.toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // Frequency and Play status indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FREQUENCY OUTPUT',
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: state.isPlaying
                      ? Colors.cyanAccent.withOpacity(0.1)
                      : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: state.isPlaying
                        ? Colors.cyanAccent.withOpacity(0.3)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.isPlaying ? Colors.cyanAccent : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.isPlaying ? 'ACTIVE' : 'MUTED',
                      style: TextStyle(
                        color: state.isPlaying ? Colors.cyanAccent : Colors.grey,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Large digital frequency display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                state.frequency.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 54.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Hz',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Note and cents offset details
          Text(
            '${note.name}${note.octave} ($centsStr cents)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          // Waveform canvas
          SizedBox(
            height: 80,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                type: state.waveformType,
                phase: _wavePhase,
                isPlaying: state.isPlaying,
                color: Colors.cyanAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Note and frequency picker card.
  Widget _buildNoteSelectorCard(ToneGeneratorState state) {
    final note = state.note;
    final int currentMidi = state.midiNumber;
    final int octave = note.octave;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PITCH CONFIGURATION',
            style: TextStyle(
              color: Colors.grey.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Note Row (C through B)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: Note.noteNames.map((name) {
              final bool isSelected = note.name == name;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    final int idx = Note.noteNames.indexOf(name);
                    final int targetMidi = 12 * (octave + 1) + idx;
                    widget.mode.setMidiNumber(targetMidi);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.0),
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.cyanAccent.withOpacity(0.15)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: isSelected
                            ? Colors.cyanAccent.withOpacity(0.6)
                            : Colors.white.withOpacity(0.06),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.6),
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Octave controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Octave',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: currentMidi >= 33 // Limit octave down so we don't go below A0
                        ? () => widget.mode.setMidiNumber(currentMidi - 12)
                        : null,
                    icon: const Icon(Icons.remove, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.04),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withOpacity(0.01),
                      disabledForegroundColor: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'OCTAVE $octave',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: currentMidi <= 96 // Limit octave up so we don't go above C8
                        ? () => widget.mode.setMidiNumber(currentMidi + 12)
                        : null,
                    icon: const Icon(Icons.add, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.04),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withOpacity(0.01),
                      disabledForegroundColor: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Fine-tuning cents slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fine-Tune (Cents)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${state.centsOffset >= 0 ? '+' : ''}${state.centsOffset.toStringAsFixed(1)} ¢',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: state.centsOffset,
            min: -50.0,
            max: 50.0,
            onChanged: (val) => widget.mode.setCentsOffset(val),
          ),
          const SizedBox(height: 16),
          // Logarithmic Frequency Sweep Slider (Hz)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frequency Sweep',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${state.frequency.toStringAsFixed(1)} Hz',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
          Slider(
            value: _freqToSlider(state.frequency),
            min: 0.0,
            max: 1.0,
            onChanged: (val) {
              final freq = _sliderToFreq(val);
              widget.mode.setFrequency(freq);
            },
          ),
          const SizedBox(height: 12),
          // Quick Hz adjustment buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildHzAdjustButton('-100', -100.0),
                _buildHzAdjustButton('-10', -10.0),
                _buildHzAdjustButton('-1', -1.0),
                _buildHzAdjustButton('-0.1', -0.1),
                const SizedBox(width: 8),
                _buildHzAdjustButton('+0.1', 0.1),
                _buildHzAdjustButton('+1', 1.0),
                _buildHzAdjustButton('+10', 10.0),
                _buildHzAdjustButton('+100', 100.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHzAdjustButton(String label, double delta) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          minimumSize: Size.zero,
          backgroundColor: Colors.white.withOpacity(0.03),
          foregroundColor: Colors.white.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6.0),
            side: BorderSide(color: Colors.white.withOpacity(0.04)),
          ),
        ),
        onPressed: () {
          final target = widget.mode.state.frequency + delta;
          widget.mode.setFrequency(target);
        },
        child: Text(
          label,
          style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Waveform and volume controls.
  Widget _buildWaveformAndVolumeCard(ToneGeneratorState state) {
    final List<Map<String, dynamic>> waveTypes = [
      {'id': 'sine', 'label': 'SINE', 'icon': Icons.circle_outlined},
      {'id': 'triangle', 'label': 'TRIANGLE', 'icon': Icons.change_history_outlined},
      {'id': 'sawtooth', 'label': 'SAWTOOTH', 'icon': Icons.insights},
      {'id': 'square', 'label': 'SQUARE', 'icon': Icons.crop_square_outlined},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOUND SETTINGS',
            style: TextStyle(
              color: Colors.grey.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Waveform selector chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: waveTypes.map((wave) {
              final String waveId = wave['id'];
              final bool isSelected = state.waveformType == waveId;

              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.mode.setWaveformType(waveId),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3.0),
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.cyanAccent.withOpacity(0.15)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: isSelected
                            ? Colors.cyanAccent.withOpacity(0.6)
                            : Colors.white.withOpacity(0.06),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          wave['icon'],
                          size: 16.0,
                          color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          wave['label'],
                          style: TextStyle(
                            color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.6),
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Volume slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    state.volume == 0.0
                        ? Icons.volume_mute
                        : (state.volume < 0.5 ? Icons.volume_down : Icons.volume_up),
                    size: 18.0,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Volume',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '${(state.volume * 100).round()}%',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: state.volume,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => widget.mode.setVolume(val),
          ),
        ],
      ),
    );
  }

  /// Big Play/Stop trigger button.
  Widget _buildPlayButton(ToneGeneratorState state) {
    return Center(
      child: GestureDetector(
        onTap: () => widget.mode.togglePlay(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state.isPlaying ? Colors.cyanAccent : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: state.isPlaying ? Colors.cyanAccent : Colors.white.withOpacity(0.1),
              width: 2.0,
            ),
            boxShadow: state.isPlaying
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 4,
                    )
                  ]
                : [],
          ),
          child: Icon(
            state.isPlaying ? Icons.stop : Icons.play_arrow,
            size: 32.0,
            color: state.isPlaying ? Colors.black : Colors.cyanAccent,
          ),
        ),
      ),
    );
  }
}

/// Custom painter to draw animated waves.
class WaveformPainter extends CustomPainter {
  final String type;
  final double phase;
  final bool isPlaying;
  final Color color;

  WaveformPainter({
    required this.type,
    required this.phase,
    required this.isPlaying,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double midY = size.height / 2;
    final double amplitude = size.height * 0.35 * (isPlaying ? 1.0 : 0.08);

    const int numCycles = 3;

    for (double x = 0; x <= size.width; x += 2) {
      final double ratio = x / size.width;
      final double u = ratio * 2 * pi * numCycles - phase;
      double v = 0.0;

      switch (type) {
        case 'sine':
          v = sin(u);
          break;
        case 'square':
          v = sin(u) >= 0.0 ? 1.0 : -1.0;
          break;
        case 'triangle':
          v = (2.0 / pi) * asin(sin(u));
          break;
        case 'sawtooth':
          v = 2.0 * ((u % (2 * pi)) / (2 * pi)) - 1.0;
          break;
      }

      // Add a fading envelope at the edges so the wave starts and ends at 0
      final double edgeFade = sin(ratio * pi);
      final double y = midY + v * amplitude * edgeFade;

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (isPlaying) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.phase != phase ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.color != color;
  }
}
