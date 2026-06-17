import 'dart:math';
import 'package:flutter/material.dart';

class NeedlePainter extends CustomPainter {
  final double cents;
  final bool hasSignal;
  final bool isLocked;
  final Color themeColor;

  NeedlePainter({
    required this.cents,
    required this.hasSignal,
    required this.isLocked,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    
    // The center of our dial arc will be positioned slightly below the widget
    final Offset center = Offset(width / 2, height * 0.95);
    final double radius = min(width / 2, height) * 0.85;

    // Define the color scheme
    final Color inactiveColor = Colors.grey.withOpacity(0.3);
    final Color accentColor = isLocked
        ? Colors.greenAccent
        : (cents > 0 ? Colors.redAccent : Colors.orangeAccent);
    
    final Color needleColor = hasSignal 
        ? (isLocked ? Colors.greenAccent : Colors.cyanAccent)
        : Colors.white.withOpacity(0.3);

    // Draw background arc
    final Paint arcPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    // Sweep from 210 degrees (-60 deg from vertical) to 330 degrees (+60 deg from vertical)
    const double startAngle = 210 * pi / 180;
    const double sweepAngle = 120 * pi / 180;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Draw the active/deviation arc showing how far off you are
    if (hasSignal && cents.abs() > 1) {
      final Paint activeArcPaint = Paint()
        ..color = accentColor.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;

      final double centsFraction = cents / 50.0; // range [-1.0, 1.0]
      final double targetAngle = 270 * pi / 180 + centsFraction * (60 * pi / 180);
      final double start = min(270 * pi / 180, targetAngle);
      final double sweep = (targetAngle - (270 * pi / 180)).abs();
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        activeArcPaint,
      );
    }

    // Draw target "in-tune" lock region tick marks (-3 to +3 cents)
    final Paint lockZonePaint = Paint()
      ..color = Colors.green.withOpacity(isLocked ? 0.3 : 0.1)
      ..style = PaintingStyle.fill;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 10),
      (270 - 3.6) * pi / 180, // roughly 3 cents width
      7.2 * pi / 180,
      true,
      lockZonePaint,
    );

    // Draw ticks and labels
    final Paint tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = -50; i <= 50; i += 5) {
      final double centsFraction = i / 50.0;
      final double angle = 270 * pi / 180 + centsFraction * (60 * pi / 180);
      
      final bool isMajor = i % 10 == 0;
      final bool isCenter = i == 0;
      
      final double tickLength = isCenter ? 14.0 : (isMajor ? 10.0 : 6.0);
      final double strokeWidth = isCenter ? 3.0 : (isMajor ? 2.0 : 1.0);
      
      Color tickColor = inactiveColor;
      if (isCenter) {
        tickColor = isLocked ? Colors.greenAccent : Colors.cyan.withOpacity(0.7);
      } else if (hasSignal) {
        if (i > 0 && cents > 0 && i <= cents) {
          tickColor = accentColor.withOpacity(0.7);
        } else if (i < 0 && cents < 0 && i >= cents) {
          tickColor = accentColor.withOpacity(0.7);
        }
      }

      tickPaint.color = tickColor;
      tickPaint.strokeWidth = strokeWidth;

      final Offset startPoint = Offset(
        center.dx + (radius - 5) * cos(angle),
        center.dy + (radius - 5) * sin(angle),
      );
      final Offset endPoint = Offset(
        center.dx + (radius - 5 - tickLength) * cos(angle),
        center.dy + (radius - 5 - tickLength) * sin(angle),
      );
      canvas.drawLine(startPoint, endPoint, tickPaint);

      // Draw label texts for major ticks (-50, -30, 0, 30, 50)
      if (i == -50 || i == -30 || i == 0 || i == 30 || i == 50) {
        String labelText = i.abs().toString();
        if (i == 0) labelText = "IN TUNE";
        else if (i < 0) labelText = "b$labelText";
        else labelText = "#$labelText";

        textPainter.text = TextSpan(
          text: labelText,
          style: TextStyle(
            color: isCenter 
                ? (isLocked ? Colors.greenAccent : Colors.grey)
                : Colors.grey.withOpacity(0.6),
            fontSize: isCenter ? 10.0 : 8.5,
            fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
          ),
        );
        textPainter.layout();

        final double labelRadius = radius - 20 - (isCenter ? 5 : 0);
        final Offset labelPos = Offset(
          center.dx + labelRadius * cos(angle) - textPainter.width / 2,
          center.dy + labelRadius * sin(angle) - textPainter.height / 2,
        );
        textPainter.paint(canvas, labelPos);
      }
    }

    // Draw Needle Shadow (glow)
    if (hasSignal) {
      final double centsFraction = cents / 50.0;
      final double needleAngle = 270 * pi / 180 + centsFraction * (60 * pi / 180);
      
      final Paint needleGlowPaint = Paint()
        ..color = needleColor.withOpacity(0.4)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      final Offset glowEndPoint = Offset(
        center.dx + (radius - 12) * cos(needleAngle),
        center.dy + (radius - 12) * sin(needleAngle),
      );
      canvas.drawLine(center, glowEndPoint, needleGlowPaint);
    }

    // Draw the actual needle line
    final double centsFraction = cents / 50.0;
    final double needleAngle = 270 * pi / 180 + centsFraction * (60 * pi / 180);
    
    final Paint needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final Offset needleEndPoint = Offset(
      center.dx + (radius - 10) * cos(needleAngle),
      center.dy + (radius - 10) * sin(needleAngle),
    );
    canvas.drawLine(center, needleEndPoint, needlePaint);

    // Draw center hub pin
    final Paint hubInner = Paint()..color = needleColor;
    final Paint hubOuter = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, 6.0, hubInner);
    canvas.drawCircle(center, 6.0, hubOuter);
  }

  @override
  bool shouldRepaint(covariant NeedlePainter oldDelegate) {
    return oldDelegate.cents != cents ||
        oldDelegate.hasSignal != hasSignal ||
        oldDelegate.isLocked != isLocked ||
        oldDelegate.themeColor != themeColor;
  }
}

/// Dynamic animated gauge wrapper that uses a TweenAnimationBuilder for smooth needle transitions.
class TunerGauge extends StatelessWidget {
  final double cents;
  final bool hasSignal;
  final bool isLocked;
  final Color themeColor;

  const TunerGauge({
    super.key,
    required this.cents,
    required this.hasSignal,
    required this.isLocked,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the interpolation speed. If there's no signal, the needle slowly drifts to center.
    // If there is signal, the needle reacts quickly to keep up with the note.
    final duration = hasSignal 
        ? const Duration(milliseconds: 90) 
        : const Duration(milliseconds: 350);

    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1.5,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: hasSignal ? cents : 0.0),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, animatedCents, child) {
            return CustomPaint(
              painter: NeedlePainter(
                cents: animatedCents,
                hasSignal: hasSignal,
                isLocked: isLocked,
                themeColor: themeColor,
              ),
            );
          },
        ),
      ),
    );
  }
}
