import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import 'fiber_noise.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback? onComplete;

  const SplashPage({super.key, this.onComplete});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _titleFade;
  late Animation<double> _textFade;
  late final AnimationController _foryouController;
  final List<_GoldParticle> _particles = [];
  final _random = Random(42);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.45, curve: Curves.easeOut)),
    );

    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.375, 0.55, curve: Curves.easeOut)),
    );

    for (int i = 0; i < 80; i++) {
      _particles.add(_GoldParticle(_random));
    }

    _foryouController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _foryouController.addListener(() => setState(() {}));

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _foryouController.forward().then((_) => widget.onComplete?.call());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _foryouController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPaperDark,
      body: FiberNoiseBackground(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _GoldParticlePainter(
                          particles: _particles,
                          progress: _controller.value.clamp(0.0, 0.875),
                          size: MediaQuery.of(context).size,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: _titleFade.value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - _titleFade.value) * 30),
                            child: ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds);
                              },
                              child: const Text('PureReader', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 4.0)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedBuilder(
                          animation: _foryouController,
                          builder: (context, child) {
                            final t = _foryouController.value;
                            if (t <= 0) return const SizedBox.shrink();
                            return Opacity(
                              opacity: t.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, sin(t * pi * 4) * 6),
                                child: SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.75,
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [Colors.white70, Colors.white, Colors.white70],
                                      stops: [0.0, 0.5 + sin(t * pi * 3) * 0.1, 1.0],
                                    ).createShader(bounds),
                                    child: const Text(
                                      'FORYOU',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 46,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 48),
                        Opacity(
                          opacity: _textFade.value,
                          child: Column(
                            children: [
                              Text('由 zyhly（zyh663 / zyh）独立编写', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('本软件遵循 MIT 开源协议', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GoldParticle {
  final double angle;
  final double speed;
  final double size;
  _GoldParticle(Random rng)
      : angle = rng.nextDouble() * 2 * pi,
        speed = 0.3 + rng.nextDouble() * 0.7,
        size = 2 + rng.nextDouble() * 4;
}

class _GoldParticlePainter extends CustomPainter {
  final List<_GoldParticle> particles;
  final double progress;
  final Size size;
  _GoldParticlePainter({required this.particles, required this.progress, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final maxR = canvasSize.shortestSide * 0.7;
    for (final p in particles) {
      final eased = Curves.easeOutCubic.transform(progress);
      final dist = eased * maxR * p.speed;
      final x = cx + cos(p.angle) * dist;
      final y = cy + sin(p.angle) * dist;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final gc = Color.lerp(const Color(0xFF4CAF50), const Color(0xFF81C784), p.speed)!;
      final paint = Paint()..color = gc.withAlpha((255 * opacity).round())..style = PaintingStyle.fill;
      final r = p.size * (1.0 - progress * 0.5);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle + progress * 3);
      canvas.drawPath(Path()..moveTo(0, -r)..lineTo(r * 0.8, 0)..lineTo(0, r)..lineTo(-r * 0.8, 0)..close(), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GoldParticlePainter o) => o.progress != progress;
}
