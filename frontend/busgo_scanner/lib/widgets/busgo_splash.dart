// ─────────────────────────────────────────────────────────────────────────────
//  BUSGO SPLASH — exact replica of admin web app animation
//  Uses Flutter PathMetrics to animate stroke draw-in (= CSS stroke-dashoffset)
//  SVG viewBox: 0 0 640 200  (translate 24,36 applied to paths below)
//
//  USAGE: BusgoSplashScreen(subtitle: 'C  L  I  E  N  T', onDone: () { ... })
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Paths (in absolute SVG 640×200 coordinates, translate already applied) ──
final _busgoStrokePaths = [
  // B — stem (i=0, delay 0)
  Path()
    ..moveTo(40, 164)
    ..lineTo(40, 36),
  // B — top bump (i=1, delay 1)
  Path()
    ..moveTo(40, 36)
    ..cubicTo(82, 36, 82, 100, 40, 100),
  // B — bottom bump (i=2, delay 2)
  Path()
    ..moveTo(40, 100)
    ..cubicTo(90, 100, 90, 164, 40, 164),
  // U (i=3)
  Path()
    ..moveTo(136, 36)
    ..lineTo(136, 116)
    ..cubicTo(136, 142.5, 157.5, 164, 184, 164)
    ..cubicTo(210.5, 164, 232, 142.5, 232, 116)
    ..lineTo(232, 36),
  // S (i=4)
  Path()
    ..moveTo(328, 64)
    ..cubicTo(328, 44, 312, 36, 296, 36)
    ..cubicTo(280, 36, 264, 46, 264, 68)
    ..cubicTo(264, 92, 284, 102, 304, 108)
    ..cubicTo(320, 114, 336, 124, 336, 140)
    ..cubicTo(336, 162, 320, 164, 300, 164)
    ..cubicTo(284, 164, 268, 154, 264, 136),
  // G (i=5)
  Path()
    ..moveTo(432, 72)
    ..cubicTo(422, 48, 408, 36, 392, 36)
    ..cubicTo(369, 36, 360, 64.6, 360, 100)
    ..cubicTo(360, 135.3, 369, 164, 392, 164)
    ..cubicTo(408, 164, 422, 152, 432, 128)
    ..lineTo(432, 100)
    ..lineTo(396, 100),
  // O (i=6)
  Path()
    ..moveTo(520, 36)
    ..cubicTo(546.5, 36, 568, 64.6, 568, 100)
    ..cubicTo(568, 135.3, 546.5, 164, 520, 164)
    ..cubicTo(493.5, 164, 472, 135.3, 472, 100)
    ..cubicTo(472, 64.6, 493.5, 36, 520, 36)
    ..close(),
];

// Stroke colours matching the admin CSS (dark tones drawn first)
const _strokeColors = [
  Color(0xFF3b3f8f), // B stem — indigo dark
  Color(0xFF6a70e0), // B top  — indigo light
  Color(0xFF3b3f8f), // B bot  — indigo dark
  Color(0xFF1a8a7a), // U — teal dark
  Color(0xFF3da55c), // S — green dark
  Color(0xFF3b3f8f), // G — indigo dark
  Color(0xFF1a8a7a), // O — teal dark
];

// Fill colours (radial gradient mid-stop, matching admin CSS rg-indigo/teal/green)
const _fillColors = [
  Color(0xFF6a70e0), // B
  Color(0xFF6a70e0),
  Color(0xFF40d8b0),
  Color(0xFF40d8b0), // U
  Color(0xFF6ae894), // S
  Color(0xFF6a70e0), // G
  Color(0xFF40d8b0), // O
];

// ── Painter ───────────────────────────────────────────────────────────────────
class _BusgoPainter extends CustomPainter {
  final List<double> strokeProg; // 0→1 per path
  final List<double> fillAlpha;  // 0→1 per path
  final double dotY;             // dot Y position (starts -60, lands at 0)
  final double dotAlpha;

  const _BusgoPainter({
    required this.strokeProg,
    required this.fillAlpha,
    required this.dotY,
    required this.dotAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale SVG 640×200 → canvas size (keeping aspect ratio, centred)
    final scaleX  = size.width / 640;
    final scaleY  = size.height / 200;
    final scale   = min(scaleX, scaleY);
    final offsetX = (size.width  - 640 * scale) / 2;
    final offsetY = (size.height - 200 * scale) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    final sw = 32.0; // SVG strokeWidth

    for (int i = 0; i < _busgoStrokePaths.length; i++) {
      final p   = _busgoStrokePaths[i];
      final sp  = strokeProg[i].clamp(0.0, 1.0);
      final fa  = fillAlpha[i].clamp(0.0, 1.0);

      if (sp <= 0 && fa <= 0) continue;

      // Extract the drawn portion of the path using PathMetrics
      Path drawn = Path();
      if (sp > 0) {
        for (final metric in p.computeMetrics()) {
          final end = metric.length * sp;
          if (end > 0) drawn.addPath(metric.extractPath(0, end), Offset.zero);
        }
      } else {
        drawn = p;
      }

      // ── Stroke layer (white/grey, mix-blend-mode: lighten in web) ──
      if (sp > 0) {
        canvas.drawPath(
          drawn,
          Paint()
            ..style       = PaintingStyle.stroke
            ..strokeWidth = sw
            ..strokeCap   = StrokeCap.round
            ..strokeJoin  = StrokeJoin.round
            ..color       = _strokeColors[i].withOpacity(sp),
        );
      }

      // ── Fill/colour layer (blooms in after stroke) ──
      if (fa > 0) {
        canvas.drawPath(
          p,
          Paint()
            ..style       = PaintingStyle.stroke
            ..strokeWidth = sw
            ..strokeCap   = StrokeCap.round
            ..strokeJoin  = StrokeJoin.round
            ..color       = _fillColors[i].withOpacity(fa),
        );
      }
    }

    // ── Dot (teal circle, drops from above) ──
    if (dotAlpha > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(24, 28 + dotY, 18, 18),
          const Radius.circular(9)),
        Paint()..color = const Color(0xFF40d8b0).withOpacity(dotAlpha),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BusgoPainter old) => true;
}

// ── BusgoSplashScreen widget ──────────────────────────────────────────────────
class BusgoSplashScreen extends StatefulWidget {
  final String   subtitle; // e.g. 'C  L  I  E  N  T'
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

  // One controller per SVG path (7 paths: 3 for B, 1 each USGO)
  late List<AnimationController> _strokeCtrls;
  late List<AnimationController> _fillCtrls;

  // Dot drop
  late AnimationController _dotCtrl;
  late Animation<double>   _dotY;
  late Animation<double>   _dotAlpha;

  // Subtitle
  late AnimationController _subtitleCtrl;

  // Fade out
  late AnimationController _fadeCtrl;

  // Timings matching admin JS animation:
  //   delay: 600 + i * 140   duration: 700   (stroke)
  //   fills bloom: lettersDone - 200 + dist*40  duration: 500
  //   dot drops:   lettersDone - 200
  static const _strokeDelay    = 600;  // ms base delay
  static const _strokeStagger  = 140;  // ms per path
  static const _strokeDuration = 700;  // ms
  static const _fillDuration   = 500;  // ms

  int get _lettersDoneMs =>
      _strokeDelay + 6 * _strokeStagger + _strokeDuration;

  @override
  void initState() {
    super.initState();

    // ── Stroke controllers ──────────────────────────────────────────────────
    _strokeCtrls = List.generate(7, (i) =>
        AnimationController(vsync: this,
            duration: const Duration(milliseconds: _strokeDuration)));

    _fillCtrls = List.generate(7, (i) =>
        AnimationController(vsync: this,
            duration: const Duration(milliseconds: _fillDuration)));

    // ── Dot ─────────────────────────────────────────────────────────────────
    _dotCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    _dotY = Tween<double>(begin: -300, end: 0).animate(
        CurvedAnimation(parent: _dotCtrl, curve: Curves.bounceOut));
    _dotAlpha = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _dotCtrl,
            curve: const Interval(0, 0.15, curve: Curves.linear)));

    // ── Subtitle ────────────────────────────────────────────────────────────
    _subtitleCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));

    // ── Fade out ────────────────────────────────────────────────────────────
    _fadeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Stroke draw-in: staggered delays matching admin JS
    for (int i = 0; i < 7; i++) {
      final delay = _strokeDelay + i * _strokeStagger;
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) _strokeCtrls[i].forward();
      });
    }

    // Dot drops at: lettersDone - 200
    Future.delayed(Duration(milliseconds: _lettersDoneMs - 200), () {
      if (mounted) _dotCtrl.forward();
    });

    // Fills bloom in staggered from centre outward
    // dist = |i - mid| where mid = 3.0
    for (int i = 0; i < 7; i++) {
      final mid   = 3.0;
      final dist  = (i - mid).abs();
      final delay = (_lettersDoneMs - 200) + (dist * 40).round();
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) _fillCtrls[i].forward();
      });
    }

    // Subtitle: fills.duration + 200
    final subtitleDelay = _lettersDoneMs + _fillDuration + 200;
    await Future.delayed(Duration(milliseconds: subtitleDelay));
    if (!mounted) return;
    _subtitleCtrl.forward();

    // Hold 1.2s then fade out
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    await _fadeCtrl.forward();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    for (final c in _strokeCtrls) c.dispose();
    for (final c in _fillCtrls)   c.dispose();
    _dotCtrl.dispose();
    _subtitleCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // SVG aspect ratio = 640:200 = 3.2:1
    // Display at 88% screen width with proportional height
    final svgW  = size.width * 0.88;
    final svgH  = svgW / 3.2;

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn)),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF0B0E1A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── BUSGO animated SVG ──────────────────────────────────────
              AnimatedBuilder(
                animation: Listenable.merge(
                    [..._strokeCtrls, ..._fillCtrls, _dotCtrl]),
                builder: (_, __) => SizedBox(
                  width:  svgW,
                  height: svgH + 20, // extra room for dot above
                  child: CustomPaint(
                    painter: _BusgoPainter(
                      strokeProg: _strokeCtrls.map((c) => c.value).toList(),
                      fillAlpha:  _fillCtrls.map((c) => c.value).toList(),
                      dotY:       _dotY.value,
                      dotAlpha:   _dotAlpha.value,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Subtitle (e.g. "C  L  I  E  N  T") ─────────────────────
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
                      fontSize: 15,
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



