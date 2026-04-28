import 'dart:math';
import 'package:flutter/material.dart';

class DominoSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const DominoSplashScreen({super.key, required this.onComplete});

  @override
  State<DominoSplashScreen> createState() => _DominoSplashScreenState();
}

class _DominoSplashScreenState extends State<DominoSplashScreen>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _translations;
  late final List<Animation<double>> _rotations;
  late final List<Animation<double>> _opacities;
  late final AnimationController _fadeOutController;
  late final Animation<double> _fadeOut;

  static const int _count = 7;
  static const Duration _cycleDuration = Duration(milliseconds: 2800);
  static const Duration _totalDuration = Duration(milliseconds: 3500);

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(_count, (i) {
      final controller = AnimationController(vsync: this, duration: _cycleDuration);
      // Stagger: each bar starts 0.4s earlier in the cycle
      final delay = (i * 400) / _cycleDuration.inMilliseconds;
      // We simulate negative delay by starting at a position in the cycle
      Future.delayed(Duration.zero, () {
        controller.forward(from: delay);
        controller.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            controller.forward(from: 0);
          }
        });
      });
      return controller;
    });

    // Keyframes: translateX positions (normalized 0..1 → will be scaled)
    // 0%    → x:0,     rot:0,    op:0
    // 14.28 → x:-15,   rot:0,    op:1
    // 28.56 → x:-30,   rot:0,    op:1
    // 37.12 → x:-39,   rot:0,    op:1
    // 42.84 → x:-45,   rot:10,   op:1
    // 57.12 → x:-60,   rot:40,   op:1
    // 71.4  → x:-75,   rot:62,   op:1
    // 85.68 → x:-90,   rot:72,   op:1
    // 100%  → x:-105,  rot:74,   op:0

    _translations = _controllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0, end: -15), weight: 14.28),
        TweenSequenceItem(tween: Tween(begin: -15, end: -30), weight: 14.28),
        TweenSequenceItem(tween: Tween(begin: -30, end: -39), weight: 8.56),
        TweenSequenceItem(tween: Tween(begin: -39, end: -45), weight: 5.72),
        TweenSequenceItem(tween: Tween(begin: -45, end: -60), weight: 14.28),
        TweenSequenceItem(tween: Tween(begin: -60, end: -75), weight: 14.28),
        TweenSequenceItem(tween: Tween(begin: -75, end: -90), weight: 14.28),
        TweenSequenceItem(tween: Tween(begin: -90, end: -105), weight: 14.32),
      ]).animate(c);
    }).toList();

    _rotations = _controllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0, end: 0), weight: 37.12),
        TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 5.72),
        TweenSequenceItem(tween: Tween(begin: 10, end: 40), weight: 14.28),
        TweenSequenceItem(tween: Tween(begin: 40, end: 62), weight: 14.28),
        TweenSequenceItem(tween: Tween(begin: 62, end: 72), weight: 14.28),
        TweenSequenceItem(tween: Tween(begin: 72, end: 74), weight: 14.32),
      ]).animate(c);
    }).toList();

    _opacities = _controllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 14.28),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 71.4),
        TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 14.32),
      ]).animate(c);
    }).toList();

    // Fade out the whole screen after the total duration
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
    for (final c in _controllers) {
      c.dispose();
    }
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeOut,
      child: Scaffold(
        backgroundColor: const Color(0xFF1a6aaf),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Domino loader
              SizedBox(
                width: 200,
                height: 60,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: List.generate(_count, (i) {
                    return AnimatedBuilder(
                      animation: _controllers[i],
                      builder: (context, child) {
                        final tx = _translations[i].value * 1.8; // scale up
                        final rot = _rotations[i].value * pi / 180;
                        final op = _opacities[i].value;
                        return Transform.translate(
                          offset: Offset(tx, 0),
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.rotationZ(rot),
                            child: Opacity(
                              opacity: op.clamp(0, 1),
                              child: Container(
                                width: 6,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
              const SizedBox(height: 40),
              // Loading text
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontFamily: 'sans-serif',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


