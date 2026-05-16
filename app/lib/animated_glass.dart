import 'package:flutter/material.dart';

import 'glass_widgets.dart';

class SlideFadeIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;

  const SlideFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.14),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(
            beginOffset.dx * (1 - value) * 40,
            beginOffset.dy * (1 - value) * 120,
          ),
          child: Opacity(opacity: value, child: child),
        );
      },
    );
  }
}

class GlassSection extends StatelessWidget {
  final Widget child;

  const GlassSection({super.key, required this.child});

  @override
  Widget build(BuildContext context) => GlassPanel(child: child);
}

class StaggeredSlideColumn extends StatelessWidget {
  final List<Widget> children;
  const StaggeredSlideColumn({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 360 + i * 55),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * 20),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: children[i],
          ),
          if (i != children.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
