import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';

class CurledPageTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget currentPage;
  final Widget nextPage;
  final bool isNext;

  const CurledPageTransition({
    super.key,
    required this.animation,
    required this.currentPage,
    required this.nextPage,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(animation.value);

        return Stack(
          children: [
            // Underlying page — hidden during flip
            Positioned.fill(
              child: Opacity(
                opacity: t > 0.95 ? 1.0 : 0.0,
                child: nextPage,
              ),
            ),
            // Current page — curled
            if (t < 0.95)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _CurledPagePainter(
                      progress: t,
                      isNext: isNext,
                      backgroundColor: kPaperDark,
                    ),
                    child: currentPage,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CurledPagePainter extends CustomPainter {
  final double progress;
  final bool isNext;
  final Color backgroundColor;

  _CurledPagePainter({
    required this.progress,
    required this.isNext,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final w = size.width;
    final h = size.height;

    // Shadow layer for paper thickness
    final shadowGradient = isNext
        ? LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              Colors.black.withAlpha((120 * progress).round()),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25],
          )
        : LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withAlpha((120 * progress).round()),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25],
          );

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = shadowGradient.createShader(Rect.fromLTWH(0, 0, w, h)));

    // Curved edge — bezier curl
    final curlX = isNext ? w * (1 - progress) : w * progress;
    final curlStrength = 30 * sin(progress * pi);
    final cpOffset = isNext ? curlStrength : -curlStrength;

    final edgePath = Path();
    if (isNext) {
      edgePath.moveTo(curlX, 0);
      edgePath.cubicTo(curlX + cpOffset, h * 0.35, curlX + cpOffset, h * 0.65, curlX, h);
    } else {
      edgePath.moveTo(curlX, 0);
      edgePath.cubicTo(curlX + cpOffset, h * 0.35, curlX + cpOffset, h * 0.65, curlX, h);
    }

    // Highlight on the curl
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: isNext ? Alignment.centerRight : Alignment.centerLeft,
        end: isNext ? Alignment.centerLeft : Alignment.centerRight,
        colors: [
          kGold.withAlpha((40 * progress).round()),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(
      Rect.fromLTWH(isNext ? curlX - 8 : curlX - 8, 0, 16, h),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CurledPagePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isNext != isNext;
}
