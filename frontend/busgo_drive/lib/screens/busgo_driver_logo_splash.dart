import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// BUSGO Driver branded logo splash screen.
/// Sequence: stroke-draw "BUSGO" → color fill + particles →
/// steering wheel spins in → "DRIVER" text slides up → fade out.
class BusgoDriverLogoSplash extends StatefulWidget {
  final VoidCallback onComplete;
  const BusgoDriverLogoSplash({super.key, required this.onComplete});

  @override
  State<BusgoDriverLogoSplash> createState() => _BusgoDriverLogoSplashState();
}

class _BusgoDriverLogoSplashState extends State<BusgoDriverLogoSplash>
    with TickerProviderStateMixin {
  // Letter stroke draw
  late final AnimationController _drawController;
  late final Animation<double> _drawProgress;

  // Fill
  late final AnimationController _fillController;
  late final Animation<double> _fillOpacity;

  // Steering wheel spin-in
  late final AnimationController _wheelController;
  late final Animation<double> _wheelScale;
  late final Animation<double> _wheelRotation;
  late final Animation<double> _wheelOpacity;

  // "DRIVER" text
  late final AnimationController _driverTextController;
  late final Animation<double> _driverOpacity;
  late final Animation<Offset> _driverSlide;

  // Road line animation (decorative)
  late final AnimationController _roadLineController;

  // Particles
  late final AnimationController _particleController;
  final List<_Particle> _particles = [];
  final Random _rng = Random();

  // Fade out
  late final AnimationController _fadeOutController;
  late final Animation<double> _fadeOut;

  // BUSGO Drive brand colors
  static const _bgColor = Color(0xFF0F172A);     // slate-900
  static const _primaryBlue = Color(0xFF3B82F6);  // blue-500
  static const _accentAmber = Color(0xFFFBBF24);  // amber-400
  static const _accentGreen = Color(0xFF22C55E);  // green-500
  static const _accentRed = Color(0xFFEF4444);    // red-500

  @override
  void initState() {
    super.initState();

    // 1. Draw letters — 1.8s
    _drawController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800),
    );
    _drawProgress = CurvedAnimation(parent: _drawController, curve: Curves.easeOutQuad);

    // 2. Fill — 0.6s
    _fillController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _fillOpacity = CurvedAnimation(parent: _fillController, curve: Curves.easeIn);

    // 3. Steering wheel spin-in — 1.0s
    _wheelController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000),
    );
    _wheelScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _wheelController, curve: Curves.elasticOut),
    );
    _wheelRotation = Tween<double>(begin: -2 * pi, end: 0).animate(
      CurvedAnimation(parent: _wheelController, curve: Curves.easeOutCubic),
    );
    _wheelOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _wheelController, curve: const Interval(0, 0.3, curve: Curves.easeIn)),
    );

    // 4. "DRIVER" text slide
    _driverTextController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );
    _driverOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _driverTextController, curve: Curves.easeOut),
    );
    _driverSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _driverTextController, curve: Curves.easeOutCubic),
    );

    // 5. Road line (decorative)
    _roadLineController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    );

    // 6. Particles
    _particleController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    );

    // 7. Fade out
    _fadeOutController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn),
    );

    _startSequence();
  }

  void _startSequence() async {
    // Phase 1: Draw letter strokes
    await _drawController.forward();

    // Phase 2: Fill + particles
    _spawnParticles();
    _particleController.forward();
    await _fillController.forward();

    // Phase 3: Steering wheel spins in
    await _wheelController.forward();

    // Phase 4: "DRIVER" text + road line
    _roadLineController.forward();
    await _driverTextController.forward();

    // Pause
    await Future.delayed(const Duration(milliseconds: 500));

    // Phase 5: Fade out
    if (mounted) {
      await _fadeOutController.forward();
      if (mounted) widget.onComplete();
    }
  }

  void _spawnParticles() {
    final colors = [_primaryBlue, _accentAmber, _accentGreen, _accentRed, Colors.white];
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: 0.2 + _rng.nextDouble() * 0.6,
        y: 0.32 + _rng.nextDouble() * 0.12,
        vx: (_rng.nextDouble() - 0.5) * 0.4,
        vy: (_rng.nextDouble() - 0.5) * 0.4,
        radius: 2 + _rng.nextDouble() * 4,
        color: colors[_rng.nextInt(colors.length)],
      ));
    }
  }

  @override
  void dispose() {
    _drawController.dispose();
    _fillController.dispose();
    _wheelController.dispose();
    _driverTextController.dispose();
    _roadLineController.dispose();
    _particleController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeOut,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: Stack(
          children: [
            // Particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleController.value,
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // BUSGO letters
                  SizedBox(
                    width: 280,
                    height: 100,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_drawController, _fillController]),
                      builder: (context, _) => CustomPaint(
                        painter: _BusgoLetterPainter(
                          drawProgress: _drawProgress.value,
                          fillOpacity: _fillOpacity.value,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Steering wheel + "DRIVER" text row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Steering wheel icon (spins in)
                      AnimatedBuilder(
                        animation: _wheelController,
                        builder: (context, _) {
                          return Opacity(
                            opacity: _wheelOpacity.value.clamp(0, 1),
                            child: Transform.scale(
                              scale: _wheelScale.value.clamp(0, 1.2),
                              child: Transform.rotate(
                                angle: _wheelRotation.value,
                                child: Icon(
                                  Icons.drive_eta_rounded,
                                  size: 28,
                                  color: _accentAmber,
                                  shadows: [
                                    Shadow(
                                      color: _accentAmber.withOpacity(0.5),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 10),

                      // "DRIVER" text
                      SlideTransition(
                        position: _driverSlide,
                        child: FadeTransition(
                          opacity: _driverOpacity,
                          child: const Text(
                            'DRIVER',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Animated road line (decorative divider)
                  AnimatedBuilder(
                    animation: _roadLineController,
                    builder: (context, _) {
                      final width = 200.0 * _roadLineController.value;
                      return SizedBox(
                        width: 200,
                        height: 4,
                        child: Stack(
                          children: [
                            // Base line
                            Center(
                              child: Container(
                                width: width,
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      _accentAmber.withOpacity(0.6),
                                      _accentAmber,
                                      _accentAmber.withOpacity(0.6),
                                      Colors.transparent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                            // Glow
                            Center(
                              child: Container(
                                width: width * 0.6,
                                height: 4,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: _accentAmber.withOpacity(0.3 * _roadLineController.value),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 50),

                  // Loading spinner
                  AnimatedBuilder(
                    animation: _driverTextController,
                    builder: (context, _) {
                      if (_driverTextController.value < 0.5) return const SizedBox.shrink();
                      return Opacity(
                        opacity: (_driverTextController.value - 0.5) * 2,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              _accentAmber.withOpacity(0.6),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// BUSGO Letter Painter — draws "BUSGO" with stroke + fill
// ════════════════════════════════════════════════════════════════════════
class _BusgoLetterPainter extends CustomPainter {
  final double drawProgress;
  final double fillOpacity;

  _BusgoLetterPainter({required this.drawProgress, required this.fillOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final letters = _buildLetterPaths(size);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    // Driver-themed gradient: blue/amber alternating
    final gradientColors = [
      const Color(0xFF3B82F6), // blue
      const Color(0xFFFBBF24), // amber
      const Color(0xFF3B82F6), // blue
      const Color(0xFFFBBF24), // amber
      const Color(0xFF22C55E), // green
    ];

    for (int i = 0; i < letters.length; i++) {
      final path = letters[i];
      final metrics = path.computeMetrics().toList();

      final letterDelay = i * 0.12;
      final letterProgress = ((drawProgress - letterDelay) / (1.0 - letterDelay * letters.length / (letters.length - 1)))
          .clamp(0.0, 1.0);

      // Draw stroke
      for (final metric in metrics) {
        final extractPath = metric.extractPath(0, metric.length * letterProgress);
        canvas.drawPath(extractPath, strokePaint);
      }

      // Draw fill
      if (fillOpacity > 0) {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = gradientColors[i % gradientColors.length].withOpacity(fillOpacity * 0.85);
        canvas.drawPath(path, fillPaint);

        final topStroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withOpacity(fillOpacity);
        canvas.drawPath(path, topStroke);
      }
    }
  }

  List<Path> _buildLetterPaths(Size size) {
      final w = size.width;
      final h = size.height;
      final unitW = w / 5.2;
      final baseline = h * 0.82;
      final top = h * 0.18;
      final mid = (top + baseline) / 2;
      final letterH = baseline - top;
      final r = letterH * 0.22;
      final gap = unitW * 0.12;

      // B
      final b = Path();
      final bx = gap;
      final bw = unitW * 0.7;
      b.moveTo(bx, baseline);
      b.lineTo(bx, top);
      b.lineTo(bx + bw * 0.6, top);
      b.cubicTo(bx + bw, top, bx + bw, mid - 4, bx + bw * 0.6, mid - 4);
      b.lineTo(bx, mid - 4);
      b.lineTo(bx, mid + 4);
      b.lineTo(bx + bw * 0.65, mid + 4);
      b.cubicTo(bx + bw * 1.05, mid + 4, bx + bw * 1.05, baseline, bx + bw * 0.65, baseline);
      b.close();

      // U
      final u = Path();
      final ux = unitW * 1.05;
      final uw = unitW * 0.7;
      u.moveTo(ux, top);
      u.lineTo(ux, baseline - letterH * 0.35);
      u.cubicTo(ux, baseline + 4, ux + uw, baseline + 4, ux + uw, baseline - letterH * 0.35);
      u.lineTo(ux + uw, top);

      // S
      final s = Path();
      final sx = unitW * 2.0;
      final sw = unitW * 0.72;
      final sTopR = letterH * 0.26;
      final sBotR = letterH * 0.28;
      s.moveTo(sx + sw * 0.85, top + sTopR * 0.5);
      s.cubicTo(sx + sw * 0.7, top - 2, sx + sw * 0.3, top - 2, sx + sw * 0.15, top + sTopR * 0.3);
      s.cubicTo(sx - sw * 0.08, top + sTopR, sx - sw * 0.05, mid - 6, sx + sw * 0.2, mid - 2);
      s.lineTo(sx + sw * 0.55, mid + 2);
      s.cubicTo(sx + sw * 1.1, mid + 8, sx + sw * 1.08, baseline - sBotR * 0.3, sx + sw * 0.85, baseline - sBotR * 0.1);
      s.cubicTo(sx + sw * 0.65, baseline + 4, sx + sw * 0.3, baseline + 4, sx + sw * 0.12, baseline - sBotR * 0.5);

      // G
      final g = Path();
      final gx = unitW * 2.95;
      final gw = unitW * 0.75;
      final gcx = gx + gw * 0.5;
      final gcy = mid;
      final grx = gw * 0.5;
      final gry = letterH * 0.44;
      g.moveTo(gx + gw * 0.8, top + letterH * 0.15);
      g.cubicTo(gx + gw * 0.6, top - 2, gx + gw * 0.2, top - 2, gx + gw * 0.05, top + letterH * 0.2);
      g.cubicTo(gx - gw * 0.1, top + letterH * 0.45, gx - gw * 0.1, baseline - letterH * 0.45, gx + gw * 0.05, baseline - letterH * 0.2);
      g.cubicTo(gx + gw * 0.2, baseline + 2, gx + gw * 0.6, baseline + 2, gx + gw * 0.8, baseline - letterH * 0.15);
      g.lineTo(gx + gw * 0.8, mid + 2);
      g.lineTo(gx + gw * 0.45, mid + 2);

      // O
      final o = Path();
      final ox = unitW * 3.95;
      final ow = unitW * 0.72;
      final ocx = ox + ow * 0.5;
      final ocy = mid;
      o.addOval(Rect.fromCenter(
        center: Offset(ocx, ocy),
        width: ow,
        height: letterH * 0.82,
      ));

      return [b, u, s, g, o];
    }

  @override
  bool shouldRepaint(_BusgoLetterPainter old) =>
      old.drawProgress != drawProgress || old.fillOpacity != fillOpacity;
}

// ════════════════════════════════════════════════════════════════════════
// Particle system
// ════════════════════════════════════════════════════════════════════════
class _Particle {
  double x, y, vx, vy, radius;
  Color color;
  _Particle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.radius, required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final cx = (p.x + p.vx * progress) * size.width;
      final cy = (p.y + p.vy * progress) * size.height;
      final op = (1 - progress).clamp(0.0, 1.0);
      final r = p.radius * (1 - progress * 0.5);
      final paint = Paint()
        ..color = p.color.withOpacity(op)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}







