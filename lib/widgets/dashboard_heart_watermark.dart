import 'package:flutter/material.dart';

/// Semi-transparent heart + EKG line watermark for the dashboard hero.
class DashboardHeartWatermark extends StatelessWidget {
  const DashboardHeartWatermark({
    super.key,
    this.size = 132,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DashboardHeartPainter(
          color: color ?? Colors.white.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _DashboardHeartPainter extends CustomPainter {
  _DashboardHeartPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final heartPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final heart = Path()
      ..moveTo(w * 0.5, h * 0.88)
      ..cubicTo(w * 0.08, h * 0.58, w * 0.08, h * 0.22, w * 0.28, h * 0.18)
      ..cubicTo(w * 0.42, h * 0.15, w * 0.5, h * 0.28, w * 0.5, h * 0.36)
      ..cubicTo(w * 0.5, h * 0.28, w * 0.58, h * 0.15, w * 0.72, h * 0.18)
      ..cubicTo(w * 0.92, h * 0.22, w * 0.92, h * 0.58, w * 0.5, h * 0.88);

    canvas.drawPath(heart, heartPaint);

    final pulsePaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.038
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final midY = h * 0.48;
    final pulse = Path()
      ..moveTo(w * 0.14, midY)
      ..lineTo(w * 0.34, midY)
      ..lineTo(w * 0.40, midY - h * 0.12)
      ..lineTo(w * 0.46, midY + h * 0.14)
      ..lineTo(w * 0.52, midY - h * 0.06)
      ..lineTo(w * 0.58, midY)
      ..lineTo(w * 0.86, midY);

    canvas.drawPath(pulse, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _DashboardHeartPainter oldDelegate) =>
      oldDelegate.color != color;
}
