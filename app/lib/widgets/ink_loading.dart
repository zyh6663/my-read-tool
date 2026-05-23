import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';

class InkLoading extends StatefulWidget {
  final double size;

  const InkLoading({super.key, this.size = 64});

  @override
  State<InkLoading> createState() => _InkLoadingState();
}

class _InkLoadingState extends State<InkLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _BookFlipPainter(
              progress: _controller.value,
              color: kGold,
            ),
          );
        },
      ),
    );
  }
}

class _BookFlipPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BookFlipPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final bookW = size.width * 0.5;
    final bookH = size.height * 0.6;
    final spineX = cx;

    // Shadow under the book
    final shadowPaint = Paint()
      ..color = color.withAlpha((30 + 20 * sin(progress * pi)).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + bookH * 0.5 + 4), width: bookW * 1.0, height: 8),
      shadowPaint,
    );

    // Left page — flips 0 to -60 degrees
    final leftFlip = (progress < 0.5)
        ? Curves.easeInOut.transform(progress * 2) * (-pi / 3)
        : Curves.easeInOut.transform((1 - progress) * 2) * (-pi / 3);

    // Right page — flips 0 to +60 degrees, offset by half cycle
    final rightProgress = (progress + 0.5) % 1.0;
    final rightFlip = (rightProgress < 0.5)
        ? Curves.easeInOut.transform(rightProgress * 2) * (pi / 3)
        : Curves.easeInOut.transform((1 - rightProgress) * 2) * (pi / 3);

    final pagePaint = Paint()
      ..color = kPaperWarm
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = color.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Left half-page
    canvas.save();
    canvas.translate(spineX, cy);
    final leftMatrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001);
    leftMatrix.rotateY(leftFlip);
    canvas.transform(leftMatrix.storage);
    final leftRect = RRect.fromLTRBR(-bookW / 2, -bookH / 2, 0, bookH / 2, const Radius.circular(2));
    canvas.drawRRect(leftRect, pagePaint);
    canvas.drawRRect(leftRect, outlinePaint);
    // Page line
    canvas.drawLine(Offset(-bookW / 2 + 3, -bookH / 4), Offset(-bookW / 2 + 3, bookH / 3), Paint()..color = color.withAlpha(30)..strokeWidth = 0.5);
    canvas.restore();

    // Right half-page
    canvas.save();
    canvas.translate(spineX, cy);
    final rightMatrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001);
    rightMatrix.rotateY(rightFlip);
    canvas.transform(rightMatrix.storage);
    final rightRect = RRect.fromLTRBR(0, -bookH / 2, bookW / 2, bookH / 2, const Radius.circular(2));
    canvas.drawRRect(rightRect, pagePaint);
    canvas.drawRRect(rightRect, outlinePaint);
    canvas.drawLine(Offset(bookW / 2 - 3, -bookH / 4), Offset(bookW / 2 - 3, bookH / 3), Paint()..color = color.withAlpha(30)..strokeWidth = 0.5);
    canvas.restore();

    // Spine line
    canvas.drawLine(
      Offset(spineX, cy - bookH / 2),
      Offset(spineX, cy + bookH / 2),
      Paint()..color = color.withAlpha(150)..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _BookFlipPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
