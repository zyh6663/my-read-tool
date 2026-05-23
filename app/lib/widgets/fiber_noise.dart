import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';

class FiberNoisePainter extends CustomPainter {
  final _rng = Random(17);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < 300; i++) {
      final x = _rng.nextDouble() * size.width;
      final y = _rng.nextDouble() * size.height;
      final angle = _rng.nextDouble() * pi;
      final len = 4 + _rng.nextDouble() * 12;
      final alpha = (0.03 + _rng.nextDouble() * 0.03);
      paint.color = kGold.withAlpha((255 * alpha).round());
      canvas.drawLine(
        Offset(x, y),
        Offset(x + cos(angle) * len, y + sin(angle) * len),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FiberNoiseBackground extends StatelessWidget {
  final Widget child;

  const FiberNoiseBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: kPaperDark),
        Positioned.fill(
          child: CustomPaint(painter: FiberNoisePainter()),
        ),
        child,
      ],
    );
  }
}
