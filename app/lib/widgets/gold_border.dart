import 'package:flutter/material.dart';

import '../main.dart';

class GoldBorder extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double borderWidth;

  const GoldBorder({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.borderWidth = 1,
  });

  static Widget wrap(Widget child, {EdgeInsetsGeometry padding = const EdgeInsets.all(16), BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(16))}) {
    return GoldBorder(padding: padding, borderRadius: borderRadius, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: kGold.withAlpha(60), width: borderWidth),
        boxShadow: [
          BoxShadow(color: kGold.withAlpha(20), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: kPaperDark.withAlpha(180), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}
