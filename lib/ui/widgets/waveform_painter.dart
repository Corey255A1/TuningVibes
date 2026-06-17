import 'dart:math';
import 'package:flutter/material.dart';

/// Renders a real-time glowing waveform from audio samples.
class WaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;
  final bool hasSignal;

  WaveformPainter({
    required this.samples,
    required this.color,
    required this.hasSignal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final paint = Paint()
      ..color = color.withOpacity(hasSignal ? 0.8 : 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Glowing effect
    final glowPaint = Paint()
      ..color = color.withOpacity(hasSignal ? 0.25 : 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final path = Path();
    final double width = size.width;
    final double height = size.height;
    final double centerY = height / 2;
    
    final int len = samples.length;
    final double stepX = width / (len - 1);

    path.moveTo(0, centerY);

    // Apply a window function (Hanning-like) to fade the waveform edges to zero
    // so it doesn't clip sharply at the screen boundaries
    for (int i = 0; i < len; i++) {
      final double x = i * stepX;
      // Window coefficient goes from 0 at edges to 1 in center
      final double window = sin(pi * i / (len - 1));
      
      // Scale amplitude for display. Standard mic inputs are usually smaller
      final double sample = samples[i];
      final double amplitudeScale = hasSignal ? 1.5 : 0.2;
      final double y = centerY + sample * (height / 2) * window * amplitudeScale;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw glow first
    canvas.drawPath(path, glowPaint);
    // Draw crisp line on top
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    // Repaint on every sample update for high-frequency rendering
    return true; 
  }
}

/// Widget wrapper for the waveform that includes a RepaintBoundary for performance.
class RealtimeWaveform extends StatelessWidget {
  final List<double> samples;
  final Color color;
  final bool hasSignal;
  final double height;

  const RealtimeWaveform({
    super.key,
    required this.samples,
    required this.color,
    required this.hasSignal,
    this.height = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: WaveformPainter(
          samples: samples,
          color: color,
          hasSignal: hasSignal,
        ),
      ),
    );
  }
}
