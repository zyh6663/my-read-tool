import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';

class InkDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kGold.withAlpha(77)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    path.moveTo(0, midY);
    for (double x = 0; x <= w; x += 2) {
      final t = x / w;
      final wave = sin(t * pi * 2.5) * (1 - t) * (1.2 + sin(t * 7) * 0.8);
      path.lineTo(x, midY + wave * h * 0.35);
    }

    canvas.drawPath(path, paint);

    final fadePaint = Paint()
      ..color = kGold.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(path, fadePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class InkDivider extends StatelessWidget {
  const InkDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: CustomPaint(painter: InkDividerPainter()),
    );
  }
}
