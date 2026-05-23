import 'package:flutter/material.dart';

import '../main.dart';

class ShimmerGold extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const ShimmerGold({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<ShimmerGold> createState() => _ShimmerGoldState();
}

class _ShimmerGoldState extends State<ShimmerGold>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                kGold.withAlpha(0),
                kGold.withAlpha(80),
                kGold.withAlpha(160),
                kGold.withAlpha(80),
                kGold.withAlpha(0),
              ],
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
              begin: Alignment(
                -1.0 + _controller.value * 2,
                0,
              ),
              end: Alignment(
                1.0 + _controller.value * 2,
                0,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
