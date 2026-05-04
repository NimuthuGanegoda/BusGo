import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── BUSGO letter paths (SVG 640×200, translate(24,36) applied) ──────────────
List<Path> _buildPaths() => [
  // B stem
  Path()..moveTo(40,164)..lineTo(40,36),
  // B top bump
  Path()..moveTo(40,36)..cubicTo(82,36,82,100,40,100),
  // B bottom bump
  Path()..moveTo(40,100)..cubicTo(90,100,90,164,40,164),
  // U
  Path()..moveTo(136,36)..lineTo(136,116)
        ..cubicTo(136,142.5,157.5,164,184,164)
        ..cubicTo(210.5,164,232,142.5,232,116)..lineTo(232,36),
  // S
  Path()..moveTo(328,64)..cubicTo(328,44,312,36,296,36)
        ..cubicTo(280,36,264,46,264,68)..cubicTo(264,92,284,102,304,108)
        ..cubicTo(320,114,336,124,336,140)..cubicTo(336,162,320,164,300,164)
        ..cubicTo(284,164,268,154,264,136),
  // G
  Path()..moveTo(432,72)..cubicTo(422,48,408,36,392,36)
        ..cubicTo(369,36,360,64.6,360,100)..cubicTo(360,135.3,369,164,392,164)
        ..cubicTo(408,164,422,152,432,128)..lineTo(432,100)..lineTo(396,100),
  // O
  Path()..moveTo(520,36)..cubicTo(546.5,36,568,64.6,568,100)
        ..cubicTo(568,135.3,546.5,164,520,164)
        ..cubicTo(493.5,164,472,135.3,472,100)
        ..cubicTo(472,64.6,493.5,36,520,36)..close(),
];

const _strokeColors = [
  Color(0xFF6a70e0), Color(0xFF6a70e0), Color(0xFF40d8b0),
  Color(0xFF40d8b0), Color(0xFF6ae894), Color(0xFF6a70e0), Color(0xFF40d8b0),
];

const _fillColors = [
  Color(0xFF6a70e0), Color(0xFF6a70e0), Color(0xFF40d8b0),
  Color(0xFF40d8b0), Color(0xFF6ae894), Color(0xFF6a70e0), Color(0xFF40d8b0),
];

// ── Painter ───────────────────────────────────────────────────────────────────
class _BusgoPainter extends CustomPainter {
  final List<Path>   paths;
  final List<double> strokeProg;
  final List<double> fillAlpha;

  const _BusgoPainter({
    required this.paths,
    required this.strokeProg,
    required this.fillAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final scale   = min(size.width / 640, size.height / 200);
    final offsetX = (size.width  - 640 * scale) / 2;
    final offsetY = (size.height - 200 * scale) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    const sw = 32.0;

    for (int i = 0; i < paths.length; i++) {
      final sp = strokeProg[i].clamp(0.0, 1.0);
      final fa = fillAlpha[i].clamp(0.0, 1.0);
      if (sp <= 0 && fa <= 0) continue;

      // Stroke draw-in
      if (sp > 0 && sp < 1.0) {
        Path drawn = Path();
        for (final metric in paths[i].computeMetrics()) {
          drawn.addPath(metric.extractPath(0, metric.length * sp), Offset.zero);
        }
        canvas.drawPath(drawn, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _strokeColors[i]);
      }

      // Full stroke (sp == 1)
      if (sp >= 1.0) {
        canvas.drawPath(paths[i], Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _strokeColors[i]);
      }

      // Colour fill blooms in over stroke
      if (fa > 0) {
        canvas.drawPath(paths[i], Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _fillColors[i].withOpacity(fa));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BusgoPainter old) => true;
}

// ── BusgoSplashScreen ─────────────────────────────────────────────────────────
class BusgoSplashScreen extends StatefulWidget {
  final String subtitle;
  final VoidCallback onDone;

  const BusgoSplashScreen({
    super.key,
    required this.subtitle,
    required this.onDone,
  });

  @override
  State<BusgoSplashScreen> createState() => _BusgoSplashScreenState();
}

class _BusgoSplashScreenState extends State<BusgoSplashScreen>
    with TickerProviderStateMixin {

  late final List<Path> _paths = _buildPaths();

  late final List<AnimationController> _strokeCtrls;
  late final List<AnimationController> _fillCtrls;
  late final AnimationController _subtitleCtrl;
  late final AnimationController _fadeCtrl;

  // Per-path progress values tracked in state for setState repaints
  final List<double> _strokeProg = List.filled(7, 0.0);
  final List<double> _fillAlpha  = List.filled(7, 0.0);

  @override
  void initState() {
    super.initState();

    _strokeCtrls = List.generate(7, (i) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700)));

    _fillCtrls = List.generate(7, (i) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500)));

    _subtitleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    // Listen to each controller and update state
    for (int i = 0; i < 7; i++) {
      final idx = i;
      _strokeCtrls[i].addListener(() {
        if (mounted) setState(() => _strokeProg[idx] = _strokeCtrls[idx].value);
      });
      _fillCtrls[i].addListener(() {
        if (mounted) setState(() => _fillAlpha[idx] = _fillCtrls[idx].value);
      });
    }

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Stagger stroke draw-in: delay = 600 + i*140ms
    for (int i = 0; i < 7; i++) {
      final delay = 600 + i * 140;
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) _strokeCtrls[i].forward();
      });
    }

    // All strokes done at: 600 + 6*140 + 700 = 2140ms
    const lettersDone = 2140;

    // Fills bloom from centre outward
    for (int i = 0; i < 7; i++) {
      final dist  = (i - 3.0).abs();
      final delay = lettersDone - 200 + (dist * 40).round();
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) _fillCtrls[i].forward();
      });
    }

    // Subtitle
    await Future.delayed(const Duration(milliseconds: lettersDone + 500));
    if (!mounted) return;
    _subtitleCtrl.forward();

    // Hold then fade out
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    await _fadeCtrl.forward();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    for (final c in _strokeCtrls) c.dispose();
    for (final c in _fillCtrls)   c.dispose();
    _subtitleCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn)),
      child: Container(
        width:  double.infinity,
        height: double.infinity,
        color:  const Color(0xFF0B0E1A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // BUSGO canvas — uses LayoutBuilder to get real size
              LayoutBuilder(builder: (ctx, constraints) {
                final w = constraints.maxWidth * 0.88;
                final h = w / 3.2;
                return SizedBox(
                  width: w, height: h,
                  child: CustomPaint(
                    painter: _BusgoPainter(
                      paths:      _paths,
                      strokeProg: List.from(_strokeProg),
                      fillAlpha:  List.from(_fillAlpha),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Subtitle
              FadeTransition(
                opacity: _subtitleCtrl,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: _subtitleCtrl, curve: Curves.easeOut)),
                  child: Text(
                    widget.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4a8a9a),
                      letterSpacing: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


