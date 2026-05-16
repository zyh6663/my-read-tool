import 'dart:ui';

import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? tint;

  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderRadius = const BorderRadius.all(Radius.circular(24)), this.tint});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: (tint ?? scheme.surface).withAlpha(160),
              borderRadius: borderRadius,
              border: Border.all(color: Colors.white.withAlpha(45)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
