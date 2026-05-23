import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';

class PageFlipRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  PageFlipRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final value = animation.value.clamp(0.0, 1.0);
                final isFlipped = value > 0.5;
                final flipProgress = isFlipped ? (value - 0.5) * 2 : value * 2;

                return Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY((isFlipped ? pi / 2 - flipProgress * pi / 2 : flipProgress * pi / 2)),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: kPaperDark.withAlpha((80 * (1 - (isFlipped ? (1 - flipProgress) : flipProgress))).round()),
                          blurRadius: 20 * (isFlipped ? (1 - flipProgress) : flipProgress),
                          offset: const Offset(10, 0),
                        ),
                      ],
                    ),
                    child: isFlipped ? child : child,
                  ),
                );
              },
            );
          },
        );
}
