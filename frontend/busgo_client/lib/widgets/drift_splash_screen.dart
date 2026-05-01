import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DRIFT SPLASH — translated from CodePen "drift" animation
//  Dots flow in a tangent-wave pattern across a dark background
//  "Loading" text fades in at centre
//  After 6 seconds, dots clear upward (invisibleDuration = 3s), then onComplete
// ─────────────────────────────────────────────────────────────────────────────

class _Dot {
  double x;
  double size;
  double speed;
  double opacity;
  final double maxSize;
  final double maxSpeed;
  final double frequency;
  final double amplitude;
  final double section;
  final bool   fill;
  final Color  color;
  final double startTime; // ms

  _Dot({
    required this.x,
    required this.maxSize,
    required this.maxSpeed,
    required this.frequency,
    required this.amplitude,
    required this.section,
    required this.fill,
    required this.color,
    required this.startTime,
  })  : size    = 1,
        speed   = 0,
        opacity = 0;

  // y position — tangent wave (same formula as JS)
  double getY(double width, double height) {
    return amplitude * tan(pi * (x / width) * frequency - (x / 10)) +
        height / 2;
  }

  // move one frame
  bool tick(double width, double height, bool clearing, double now) {
    final y = getY(width, height);
    final posX = x * 2 * section;

    // clearing: speed up so dots exit top
    if (clearing) speed += 0.005;

    // ramp up speed and opacity
    if (speed < maxSpeed) speed += 0.01;
    if (opacity < 1) opacity += 0.025;

    // grow to maxSize/4 using easeInOutCubic
    if (size < maxSize / 4) {
      final elapsed = now - startTime - 1000;
      if (elapsed > 0) {
        final t = elapsed / 2000;
        final eased = _easeInOutCubic(t.clamp(0, 1));
        size = (maxSize / 4) * eased + 1;
      }
    } else if (size > maxSize / 4 + 1) {
      size -= 1;
    }

    x += speed;

    // off screen right → loop back left
    if (posX >= width + size / 2) {
      x = Random().nextDouble() * size - size * 2;
    }

    // off screen top while clearing → remove
    if (y <= size / 2 && clearing) return false; // signal removal

    return true; // keep
  }

  static double _easeInOutCubic(double t) {
    if (t < 0.5) return 4 * t * t * t;
    return 1 - pow(-2 * t + 2, 3) / 2;
  }
}

class _DriftPainter extends CustomPainter {
  final List<_Dot> dots;
  final double width;
  final double height;
  final double textOpacity;
  final bool   isClearing;

  const _DriftPainter({
    required this.dots,
    required this.width,
    required this.height,
    required this.textOpacity,
    required this.isClearing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF222222),
    );

    // Dots
    for (final d in dots) {
      final y    = d.getY(width, height);
      final posX = d.x * 2 * d.section;
      if (posX < -d.size || posX > width + d.size) continue;
      if (y < -d.size    || y    > height + d.size) continue;

      final paint = Paint()
        ..color = d.color.withOpacity(d.opacity.clamp(0, 1));

      if (d.fill) {
        canvas.drawCircle(Offset(posX, y), d.size, paint);
      } else {
        canvas.drawCircle(
          Offset(posX, y),
          d.size,
          paint..style = PaintingStyle.stroke..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DriftPainter old) => true;
}

// ── Widget ────────────────────────────────────────────────────────────────────
class DriftSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const DriftSplashScreen({super.key, required this.onComplete});

  @override
  State<DriftSplashScreen> createState() => _DriftSplashScreenState();
}

class _DriftSplashScreenState extends State<DriftSplashScreen> {
  final _rng   = Random();
  final _dots  = <_Dot>[];

  bool   _isClearing   = false;
  bool   _doneClearing = false;
  double _textOpacity  = 0;
  double _width        = 1;
  double _height       = 1;

  Ticker? _ticker;
  double  _startMs = 0;

  static const _visibleDuration   = 5000; // ms
  static const _invisibleDuration = 2500; // ms
  static const _dotCount          = 200;
  static const _amplitude         = 400.0;
  static const _frequency         = 0.075;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
    _startMs = _nowMs();
  }

  double _nowMs() =>
      DateTime.now().millisecondsSinceEpoch.toDouble();

  void _createDots() {
    final now = _nowMs();
    for (int i = 0; i < _dotCount; i++) {
      final isYellow = _rng.nextInt(4) == 0;
      _dots.add(_Dot(
        x:          _rng.nextDouble() * _width + (_rng.nextDouble() * 8 - 8),
        maxSize:    _rng.nextDouble() * 30,
        maxSpeed:   (_rng.nextDouble() * 0.45) /
                    (_width > 640 ? 3 : 4),
        frequency:  _frequency,
        amplitude:  _amplitude,
        section:    _rng.nextDouble() * 5 / 2 + 1,
        fill:       true,
        color:      isYellow ? const Color(0xFFFFFF00) : Colors.black,
        startTime:  now,
      ));
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final now       = _nowMs();
    final totalMs   = now - _startMs;

    // Start clearing after visibleDuration
    if (!_isClearing && totalMs > _visibleDuration) {
      setState(() => _isClearing = true);
    }

    // Done clearing after invisibleDuration → call onComplete
    if (_isClearing && !_doneClearing &&
        totalMs > _visibleDuration + _invisibleDuration) {
      _doneClearing = true;
      _ticker?.stop();
      widget.onComplete();
      return;
    }

    // Update text opacity
    double newTextOpacity = _textOpacity;
    if (_isClearing) {
      newTextOpacity = (_textOpacity - 0.075).clamp(0, 1);
    } else {
      newTextOpacity = (_textOpacity + 0.01).clamp(0, 1);
    }

    // Tick each dot
    _dots.removeWhere(
        (d) => !d.tick(_width, _height, _isClearing, now));

    // Refill dots if not clearing
    if (!_isClearing && _dots.length < _dotCount) {
      _createDots();
    }

    setState(() => _textOpacity = newTextOpacity);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      // Capture real dimensions first time
      if (_dots.isEmpty && constraints.maxWidth > 1) {
        _width  = constraints.maxWidth;
        _height = constraints.maxHeight;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(_createDots);
        });
      }

      return Stack(children: [
        // Drift canvas
        CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _DriftPainter(
            dots:        List.from(_dots),
            width:       _width,
            height:      _height,
            textOpacity: _textOpacity,
            isClearing:  _isClearing,
          ),
        ),

        // "Loading" text — centre
        Center(
          child: Opacity(
            opacity: _textOpacity.clamp(0, 1),
            child: Text(
              _isClearing ? 'Ready' : 'Loading',
              style: GoogleFonts.robotoMono(
                fontSize:   16,
                color:      const Color(0xFFE6E6E6),
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ]);
    });
  }
}
