import 'dart:ui';

import 'package:flutter/material.dart';

import 'widgets/gold_border.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? tint;

  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderRadius = const BorderRadius.all(Radius.circular(16)), this.tint});

  @override
  Widget build(BuildContext context) {
    return GoldBorder(
      padding: padding,
      borderRadius: borderRadius,
      child: ClipRRect(
        borderRadius: borderRadius.subtract(const BorderRadius.all(Radius.circular(1))),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white.withAlpha(220)
                    : Theme.of(context).colorScheme.surface.withAlpha(180),
                borderRadius: borderRadius.subtract(const BorderRadius.all(Radius.circular(1))),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
