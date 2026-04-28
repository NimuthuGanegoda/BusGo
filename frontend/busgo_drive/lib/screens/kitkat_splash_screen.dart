import 'dart:math';
import 'package:flutter/material.dart';

/// Android 4.4 KitKat-style loading screen.
/// Four colored dots (red, amber, green, blue) orbit and pulse
/// while the entire figure rotates 360°.
class KitkatSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const KitkatSplashScreen({super.key, required this.onComplete});

  @override
  State<KitkatSplashScreen> createState() => _KitkatSplashScreenState();
}

class _KitkatSplashScreenState extends State<KitkatSplashScreen>
    with TickerProviderStateMixin {
  // Main rotation: full figure spins 360°
  late final AnimationController _rotateController;

  // Dot size pulsation (shrink at 66%, reappear at 77%)
  late final AnimationController _dotController;

  // White flash in center
  late final AnimationController _flashController;

  // Fade out at the end
  late final AnimationController _fadeOutController;
  late final Animation<double> _fadeOut;

  static const _cycleDuration = Duration(milliseconds: 2400);
  static const _totalDuration = Duration(milliseconds: 4200);

  // KitKat colors
  static const _red = Color(0xFFFF4444);
  static const _amber = Color(0xFFFFBB33);
  static const _green = Color(0xFF99CC00);
  static const _blue = Color(0xFF33B5E5);

  @override
  void initState() {
    super.initState();

    _rotateController = AnimationController(vsync: this, duration: _cycleDuration)
      ..repeat();

    _dotController = AnimationController(vsync: this, duration: _cycleDuration)
      ..repeat();

    _flashController = AnimationController(vsync: this, duration: _cycleDuration)
      ..repeat();

    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeInOut),
    );

    Future.delayed(_totalDuration, () {
      if (mounted) {
        _fadeOutController.forward().then((_) {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _dotController.dispose();
    _flashController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  // Replicates the CSS keyframe: figure shrinks at 66% then expands back
  double _figureSize(double t) {
    const fullSize = 100.0;
    const smallSize = 38.0;
    if (t <= 0.10) return fullSize;
    if (t <= 0.66) {
      final progress = (t - 0.10) / 0.56;
      return fullSize + (smallSize - fullSize) * progress;
    }
    final progress = (t - 0.66) / 0.34;
    return smallSize + (fullSize - smallSize) * progress;
  }

  // Dot opacity/size: dims at 66%, snaps small at 77%
  double _dotScale(double t) {
    if (t <= 0.66) {
      return 1.0 - (t / 0.66) * 0.9; // fade to 0.1
    }
    if (t <= 0.77) {
      return 1.0; // snap back to full opacity but width/height → 0
    }
    return 1.0;
  }

  double _dotSizeFactor(double t) {
    if (t <= 0.66) return 1.0;
    if (t <= 0.77) {
      final p = (t - 0.66) / 0.11;
      return 1.0 - p; // shrink to 0
    }
    return 1.0;
  }

  double _dotOpacity(double t) {
    if (t <= 0.66) {
      return 1.0 - (t / 0.66) * 0.9;
    }
    return 1.0;
  }

  // White flash: appears 33-66%, peaks at 55%
  double _flashOpacity(double t) {
    if (t < 0.33 || t > 0.66) return 0;
    if (t <= 0.55) {
      return ((t - 0.33) / 0.22) * 0.6;
    }
    return 0.6 * (1 - (t - 0.55) / 0.11);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeOut,
      child: Scaffold(
        backgroundColor: const Color(0xFF222222),
        body: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_rotateController, _dotController, _flashController]),
            builder: (context, _) {
              final t = _rotateController.value;
              final angle = t * 2 * pi;
              final size = _figureSize(t);
              final dotDiameter = 38.0 * _dotSizeFactor(t);
              final opacity = _dotOpacity(t);
              final flash = _flashOpacity(t);

              return Transform.rotate(
                angle: angle,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // White flash center
                      if (flash > 0)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(flash),
                              shape: _dotSizeFactor(t) < 0.5
                                  ? BoxShape.circle
                                  : BoxShape.rectangle,
                              borderRadius: _dotSizeFactor(t) >= 0.5
                                  ? null
                                  : null,
                            ),
                          ),
                        ),

                      // Left dot — Red
                      Positioned(
                        left: 0,
                        top: (size - dotDiameter) / 2,
                        child: _buildDot(_red, dotDiameter, opacity),
                      ),

                      // Top dot — Amber
                      Positioned(
                        top: 0,
                        left: (size - dotDiameter) / 2,
                        child: _buildDot(_amber, dotDiameter, opacity),
                      ),

                      // Right dot — Green
                      Positioned(
                        right: 0,
                        top: (size - dotDiameter) / 2,
                        child: _buildDot(_green, dotDiameter, opacity),
                      ),

                      // Bottom dot — Blue
                      Positioned(
                        bottom: 0,
                        left: (size - dotDiameter) / 2,
                        child: _buildDot(_blue, dotDiameter, opacity),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDot(Color color, double diameter, double opacity) {
    return Opacity(
      opacity: opacity.clamp(0, 1),
      child: Container(
        width: diameter.clamp(0, 100),
        height: diameter.clamp(0, 100),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}



