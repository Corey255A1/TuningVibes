import 'package:flutter/material.dart';
import '../tuner_view_model.dart';
import '../../domain/tuner_models.dart';

class WaterfallPainter extends CustomPainter {
  final List<HistoryPoint> history;
  final double referencePitch;

  WaterfallPainter({
    required this.history,
    required this.referencePitch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    final double centerY = height / 2;

    // Draw horizontal grid lines for 0 cents (in tune), +20 cents, -20 cents
    final Paint gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // Center line (0 cents)
    canvas.drawLine(Offset(0, centerY), Offset(width, centerY), gridPaint);
    
    // Top and bottom boundaries (+30 and -30 cents)
    final double thirtyCentsY = height * 0.2;
    final double minusThirtyCentsY = height * 0.8;
    
    canvas.drawLine(Offset(0, thirtyCentsY), Offset(width, thirtyCentsY), gridPaint);
    canvas.drawLine(Offset(0, minusThirtyCentsY), Offset(width, minusThirtyCentsY), gridPaint);

    // Render historical points
    final int maxPoints = 150;
    final double stepX = width / maxPoints;

    final Path flatPath = Path();
    final Path sharpPath = Path();
    final Path lockedPath = Path();

    // Loop through history points. Point at history.length - 1 is the most recent (draws on the right)
    for (int i = 0; i < history.length; i++) {
      // Map history index to screen X coordinate (newer points towards the right)
      // If we have fewer than 150 points, align them to start from the right
      final int historyOffset = maxPoints - history.length;
      final double x = (i + historyOffset) * stepX;

      final point = history[i];
      final note = Note.fromFrequency(point.frequency, referenceFrequency: referencePitch);
      final double cents = note.centsDifference(point.frequency, referenceFrequency: referencePitch);
      final double clampedCents = cents.clamp(-50.0, 50.0);

      // Map cents [-50, 50] to Y [height, 0]
      // 0 cents -> centerY
      // -50 cents -> height
      // +50 cents -> 0
      final double y = centerY - (clampedCents / 50.0) * centerY;

      // Draw individual point glow/dots
      final isLocked = cents.abs() <= 3.0;
      final Color pointColor = isLocked
          ? Colors.greenAccent
          : (cents > 0 ? Colors.redAccent : Colors.orangeAccent);

      final Paint pointPaint = Paint()
        ..color = pointColor.withOpacity(point.amplitude.clamp(0.2, 0.9))
        ..style = PaintingStyle.fill;

      // Draw a vertical glowing line showing intensity/amplitude
      final double barHeight = (point.amplitude * height * 0.45).clamp(4.0, centerY);
      final Paint barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            pointColor.withOpacity(0.0),
            pointColor.withOpacity(point.amplitude.clamp(0.1, 0.4)),
            pointColor.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTRB(x - 1, y - barHeight, x + 1, y + barHeight))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawLine(Offset(x, y - barHeight), Offset(x, y + barHeight), barPaint);
      canvas.drawCircle(Offset(x, y), 2.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WaterfallPainter oldDelegate) {
    return true; // Dynamic scrolling chart
  }
}

/// Widget container for the waterfall scroll, wrapped in a RepaintBoundary
class SpectrogramWaterfall extends StatelessWidget {
  final List<HistoryPoint> history;
  final double referencePitch;
  final double height;

  const SpectrogramWaterfall({
    super.key,
    required this.history,
    required this.referencePitch,
    this.height = 70.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "PITCH ACCURACY HISTORY",
                  style: TextStyle(
                    color: Colors.grey.withOpacity(0.5),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  "◄ Live scroll",
                  style: TextStyle(
                    color: Colors.grey.withOpacity(0.4),
                    fontSize: 8.0,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: height,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.03)),
                bottom: BorderSide(color: Colors.white.withOpacity(0.03)),
              ),
            ),
            child: CustomPaint(
              painter: WaterfallPainter(
                history: history,
                referencePitch: referencePitch,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
