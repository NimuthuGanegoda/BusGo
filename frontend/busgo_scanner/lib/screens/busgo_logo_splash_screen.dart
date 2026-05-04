import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class BusgoLogoSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const BusgoLogoSplashScreen({super.key, required this.onComplete});

  @override
  State<BusgoLogoSplashScreen> createState() => _BusgoLogoSplashScreenState();
}

class _BusgoLogoSplashScreenState extends State<BusgoLogoSplashScreen>
    with TickerProviderStateMixin {
  // Letter draw animation
  late final AnimationController _drawController;
  late final Animation<double> _drawProgress;

  // Fill animation
  late final AnimationController _fillController;
  late final Animation<double> _fillOpacity;

  // "Scanner" text animation
  late final AnimationController _scannerController;
  late final Animation<double> _scannerOpacity;
  late final Animation<Offset> _scannerSlide;

  // Scan line animation
  late final AnimationController _scanLineController;
  late final Animation<double> _scanLinePosition;

  // Particles
  late final AnimationController _particleController;
  final List<_Particle> _particles = [];
  final Random _rng = Random();

  // Fade out
  late final AnimationController _fadeOutController;
  late final Animation<double> _fadeOut;

  // Colors matching BUSGO brand
  static const _bgColor = Color(0xFF0B1A2E);
  static const _primaryBlue = Color(0xFF1565C0);
  static const _accentGreen = Color(0xFF22C55E);
  static const _accentRed = Color(0xFFFF324A);
  static const _accentCyan = Color(0xFF31FFA6);

  @override
  void initState() {
    super.initState();

    // 1. Draw letters (stroke animation) — 1.8 seconds
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _drawProgress = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeOutQuad,
    );

    // 2. Fill animation — 0.6 seconds
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fillOpacity = CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeIn,
    );

    // 3. Scanner text slide up + fade in
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scannerOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeOut),
    );
    _scannerSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _scannerController,
      curve: Curves.easeOutCubic,
    ));

    // 4. Scan line sweep
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scanLinePosition = Tween<double>(begin: -0.1, end: 1.1).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    // 5. Particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 6. Fade out
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn),
    );

    _startSequence();
  }

  void _startSequence() async {
    // Phase 1: Draw letter strokes
    await _drawController.forward();

    // Phase 2: Fill letters + spawn particles
    _spawnParticles();
    _particleController.forward();
    await _fillController.forward();

    // Phase 3: Show "Scanner" text
    await _scannerController.forward();

    // Phase 4: Scan line sweep
    await _scanLineController.forward();

    // Wait a moment
    await Future.delayed(const Duration(milliseconds: 400));

    // Phase 5: Fade out and complete
    if (mounted) {
      await _fadeOutController.forward();
      if (mounted) widget.onComplete();
    }
  }

  void _spawnParticles() {
    final colors = [_primaryBlue, _accentGreen, _accentRed, _accentCyan, Colors.white];
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: 0.2 + _rng.nextDouble() * 0.6,
        y: 0.35 + _rng.nextDouble() * 0.15,
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
    _scannerController.dispose();
    _scanLineController.dispose();
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
            // Particles layer
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress: _particleController.value,
                  ),
                );
              },
            ),

            // Main content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // BUSGO logo with stroke draw + fill
                  SizedBox(
                    width: 280,
                    height: 100,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_drawController, _fillController]),
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _BusgoLetterPainter(
                            drawProgress: _drawProgress.value,
                            fillOpacity: _fillOpacity.value,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // "Scanner" text with slide + fade
                  SlideTransition(
                    position: _scannerSlide,
                    child: FadeTransition(
                      opacity: _scannerOpacity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Text(
                            'SCANNER',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 22,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 12,
                            ),
                          ),
                          // Scan line overlay
                          AnimatedBuilder(
                            animation: _scanLineController,
                            builder: (context, _) {
                              if (_scanLineController.value == 0) {
                                return const SizedBox.shrink();
                              }
                              return SizedBox(
                                width: 200,
                                height: 30,
                                child: CustomPaint(
                                  painter: _ScanLinePainter(
                                    position: _scanLinePosition.value,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Loading indicator
                  AnimatedBuilder(
                    animation: _scannerController,
                    builder: (context, _) {
                      if (_scannerController.value < 0.5) {
                        return const SizedBox.shrink();
                      }
                      return Opacity(
                        opacity: (_scannerController.value - 0.5) * 2,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              _accentGreen.withOpacity(0.6),
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
// BUSGO Letter Painter — draws "BUSGO" with stroke animation + fill
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

    final gradientColors = [
      const Color(0xFF206EFF), // blue
      const Color(0xFFFF324A), // red
      const Color(0xFF206EFF), // blue
      const Color(0xFFFF324A), // red
      const Color(0xFF31FFA6), // green
    ];

    for (int i = 0; i < letters.length; i++) {
      final path = letters[i];
      final metrics = path.computeMetrics().toList();

      // Per-letter delay: each letter starts slightly later
      final letterDelay = i * 0.12;
      final letterProgress = ((drawProgress - letterDelay) / (1.0 - letterDelay * letters.length / (letters.length - 1)))
          .clamp(0.0, 1.0);

      // Draw stroke (animated)
      for (final metric in metrics) {
        final extractPath = metric.extractPath(0, metric.length * letterProgress);
        canvas.drawPath(extractPath, strokePaint);
      }

      // Draw fill (fades in after stroke completes)
      if (fillOpacity > 0) {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = gradientColors[i % gradientColors.length].withOpacity(fillOpacity * 0.85);
        canvas.drawPath(path, fillPaint);

        // White stroke on top for definition
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
    final unitW = w / 5; // 5 letters
    final baseline = h * 0.85;
    final top = h * 0.15;
    final mid = h * 0.5;
    final letterH = baseline - top;
    final r = letterH * 0.25; // corner radius

    // B
    final b = Path();
    final bx = unitW * 0.15;
    b.moveTo(bx, baseline);
    b.lineTo(bx, top);
    b.lineTo(bx + unitW * 0.45, top);
    b.quadraticBezierTo(bx + unitW * 0.75, top, bx + unitW * 0.75, top + letterH * 0.22);
    b.quadraticBezierTo(bx + unitW * 0.75, mid - 2, bx + unitW * 0.45, mid - 2);
    b.lineTo(bx, mid - 2);
    b.moveTo(bx, mid + 2);
    b.lineTo(bx + unitW * 0.5, mid + 2);
    b.quadraticBezierTo(bx + unitW * 0.8, mid + 2, bx + unitW * 0.8, mid + letterH * 0.2);
    b.quadraticBezierTo(bx + unitW * 0.8, baseline, bx + unitW * 0.5, baseline);
    b.lineTo(bx, baseline);

    // U
    final u = Path();
    final ux = unitW * 1.1;
    u.moveTo(ux, top);
    u.lineTo(ux, baseline - r);
    u.quadraticBezierTo(ux, baseline, ux + r, baseline);
    u.lineTo(ux + unitW * 0.65 - r, baseline);
    u.quadraticBezierTo(ux + unitW * 0.65, baseline, ux + unitW * 0.65, baseline - r);
    u.lineTo(ux + unitW * 0.65, top);

    // S
    final s = Path();
    final sx = unitW * 2.05;
    s.moveTo(sx + unitW * 0.65, top + letterH * 0.15);
    s.quadraticBezierTo(sx + unitW * 0.5, top, sx + unitW * 0.32, top);
    s.quadraticBezierTo(sx, top, sx, top + letterH * 0.22);
    s.quadraticBezierTo(sx, mid - 3, sx + unitW * 0.32, mid - 3);
    s.lineTo(sx + unitW * 0.45, mid + 3);
    s.quadraticBezierTo(sx + unitW * 0.7, mid + 3, sx + unitW * 0.7, baseline - letterH * 0.2);
    s.quadraticBezierTo(sx + unitW * 0.7, baseline, sx + unitW * 0.35, baseline);
    s.quadraticBezierTo(sx + unitW * 0.1, baseline, sx, baseline - letterH * 0.15);

    // G
    final g = Path();
    final gx = unitW * 3.0;
    g.moveTo(gx + unitW * 0.7, top + letterH * 0.2);
    g.quadraticBezierTo(gx + unitW * 0.5, top, gx + unitW * 0.35, top);
    g.quadraticBezierTo(gx, top, gx, mid);
    g.quadraticBezierTo(gx, baseline, gx + unitW * 0.35, baseline);
    g.quadraticBezierTo(gx + unitW * 0.7, baseline, gx + unitW * 0.7, baseline - letterH * 0.3);
    g.lineTo(gx + unitW * 0.35, baseline - letterH * 0.3);

    // O
    final o = Path();
    final ox = unitW * 3.95;
    final ocx = ox + unitW * 0.35;
    final ocy = mid;
    final orx = unitW * 0.35;
    final ory = letterH * 0.42;
    o.addOval(Rect.fromCenter(
      center: Offset(ocx, ocy),
      width: orx * 2,
      height: ory * 2,
    ));

    return [b, u, s, g, o];
  }

  @override
  bool shouldRepaint(_BusgoLetterPainter old) =>
      old.drawProgress != drawProgress || old.fillOpacity != fillOpacity;
}

// ════════════════════════════════════════════════════════════════════════
// Scan Line Painter — green laser line sweeps across "SCANNER" text
// ════════════════════════════════════════════════════════════════════════
class _ScanLinePainter extends CustomPainter {
  final double position;
  _ScanLinePainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * position;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF22C55E).withOpacity(0.8),
          const Color(0xFF22C55E),
          const Color(0xFF22C55E).withOpacity(0.8),
          Colors.transparent,
        ],
        stops: const [0, 0.3, 0.5, 0.7, 1],
      ).createShader(Rect.fromLTWH(x - 20, 0, 40, size.height));

    canvas.drawRect(
      Rect.fromLTWH(x - 1, 0, 2, size.height),
      paint,
    );

    // Glow
    final glowPaint = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(
      Rect.fromLTWH(x - 15, 0, 30, size.height),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.position != position;
}

// ════════════════════════════════════════════════════════════════════════
// Particle system — firework-style particles burst when fill completes
// ════════════════════════════════════════════════════════════════════════
class _Particle {
  double x, y, vx, vy, radius;
  Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final currentX = (p.x + p.vx * progress) * size.width;
      final currentY = (p.y + p.vy * progress) * size.height;
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final currentRadius = p.radius * (1 - progress * 0.5);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(currentX, currentY), currentRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}









