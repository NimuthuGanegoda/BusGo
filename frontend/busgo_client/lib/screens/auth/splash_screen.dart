import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Phase control
  bool _showPhase2 = false;

  // Phase 1: Neon cube loader
  late AnimationController _cubeRotation;
  late AnimationController _cubePulse;
  late AnimationController _textPulse;

  // Phase 2: BUSGO letter reveal (like admin splash)
  late AnimationController _letterReveal;
  late AnimationController _subtitleReveal;
  late AnimationController _taglineReveal;
  late AnimationController _dotGlow;
  late AnimationController _fadeOut;

  // Letters of BUSGO
  static const _letters = ['B', 'U', 'S', 'G', 'O'];

  @override
  void initState() {
    super.initState();

    // ── Phase 1 animations ──
    _cubeRotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _cubePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _textPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // ── Phase 2 animations ──
    _letterReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _subtitleReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _taglineReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _dotGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Transition Phase 1 → Phase 2 after 3 seconds
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      setState(() => _showPhase2 = true);

      // Start Phase 2 sequence
      _letterReveal.forward().then((_) {
        if (!mounted) return;
        _dotGlow.repeat(reverse: true);
        _subtitleReveal.forward().then((_) {
          if (!mounted) return;
          _taglineReveal.forward();
        });
      });
    });

    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    final auth = context.read<AuthProvider>();
    await auth.checkSession();

    // Wait for animations to finish
    await Future.delayed(const Duration(milliseconds: 6000));

    if (!mounted) return;

    // Smooth fade-out before navigating
    await _fadeOut.forward();

    if (!mounted) return;

    // Stop all repeating animations before navigation
    _cubeRotation.stop();
    _cubePulse.stop();
    _textPulse.stop();
    _dotGlow.stop();

    if (auth.isLoggedIn && auth.currentUser != null) {
      context.read<UserProvider>().setUser(auth.currentUser!);
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _cubeRotation.stop();
    _cubePulse.stop();
    _textPulse.stop();
    _letterReveal.stop();
    _subtitleReveal.stop();
    _taglineReveal.stop();
    _dotGlow.stop();
    _fadeOut.stop();
    _cubeRotation.dispose();
    _cubePulse.dispose();
    _textPulse.dispose();
    _letterReveal.dispose();
    _subtitleReveal.dispose();
    _taglineReveal.dispose();
    _dotGlow.dispose();
    _fadeOut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF1e1e2f), Color(0xFF111122)],
          ),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
            CurvedAnimation(parent: _fadeOut, curve: Curves.easeInOut),
          ),
          child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _showPhase2
              ? _buildPhase2(key: const ValueKey('phase2'))
              : _buildPhase1(key: const ValueKey('phase1')),
        ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 1: Neon Cube Loader
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPhase1({Key? key}) {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rotating cube grid
          AnimatedBuilder(
            animation: _cubeRotation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _cubeRotation.value * 2 * pi,
                child: Transform.rotate(
                  angle: pi / 4,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      children: [
                        _buildCube(Alignment.topLeft, 0.0),
                        _buildCube(Alignment.topRight, 0.15),
                        _buildCube(Alignment.bottomRight, 0.3),
                        _buildCube(Alignment.bottomLeft, 0.45),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          // Pulsing text
          AnimatedBuilder(
            animation: _textPulse,
            builder: (context, child) {
              return Opacity(
                opacity: 0.4 + (_textPulse.value * 0.6),
                child: const Text(
                  'Loading BUSGO CLIENT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                    letterSpacing: 1.5,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCube(Alignment align, double phaseOffset) {
    return AnimatedBuilder(
      animation: _cubePulse,
      builder: (context, child) {
        final t = (_cubePulse.value + phaseOffset) % 1.0;
        final scale = 1.0 + (sin(t * pi) * 0.2);

        return Align(
          alignment: align,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00FFFF), Color(0xFF6600FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FFFF).withOpacity(0.5),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: const Color(0xFF6600FF).withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 2: BUSGO Letter-by-Letter Reveal (admin splash style)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPhase2({Key? key}) {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 3),

          // ── BUSGO letters (staggered reveal) ──
          AnimatedBuilder(
            animation: _letterReveal,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_letters.length, (i) {
                  // Each letter appears at a staggered time
                  final letterStart = i * 0.15; // 0, 0.15, 0.30, 0.45, 0.60
                  final letterEnd = letterStart + 0.35;
                  final progress = ((_letterReveal.value - letterStart) /
                          (letterEnd - letterStart))
                      .clamp(0.0, 1.0);

                  // Slide up + fade in
                  final slideY = (1.0 - progress) * 40;
                  final opacity = progress;

                  // Color: starts as stroke outline, fills to gradient
                  final strokeOpacity = progress < 0.6
                      ? (progress / 0.6).clamp(0.0, 1.0)
                      : 1.0;
                  final fillOpacity = progress > 0.5
                      ? ((progress - 0.5) / 0.5).clamp(0.0, 1.0)
                      : 0.0;

                  // Gradient colors per letter (like admin splash)
                  final colors = [
                    const Color(0xFF4a4fbf), // B - indigo
                    const Color(0xFF20a896), // U - teal
                    const Color(0xFF3dbb6c), // S - green
                    const Color(0xFF4a4fbf), // G - indigo
                    const Color(0xFF20a896), // O - teal
                  ];

                  return Transform.translate(
                    offset: Offset(0, slideY),
                    child: Opacity(
                      opacity: opacity,
                      child: Stack(
                        children: [
                          // Stroke outline
                          Text(
                            _letters[i],
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 2.0
                                ..color = colors[i]
                                    .withOpacity(strokeOpacity),
                            ),
                          ),
                          // Fill (fades in after stroke)
                          Opacity(
                            opacity: fillOpacity,
                            child: Text(
                              _letters[i],
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                                color: Colors.white
                                    .withOpacity(fillOpacity),
                                shadows: [
                                  Shadow(
                                    color: colors[i]
                                        .withOpacity(fillOpacity * 0.5),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),

          const SizedBox(height: 12),

          // ── Glowing dot (like admin splash) ──
          AnimatedBuilder(
            animation: _dotGlow,
            builder: (context, child) {
              final glowSize = 6.0 + (_dotGlow.value * 4);
              final glowOpacity = 0.5 + (_dotGlow.value * 0.5);
              return Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF20a896),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF20a896)
                          .withOpacity(glowOpacity),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // ── "A X I S" subtitle (slides up) ──
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.5),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _subtitleReveal,
              curve: Curves.easeOut,
            )),
            child: FadeTransition(
              opacity: _subtitleReveal,
              child: const Text(
                'C  L  I  E  N  T',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4a8a9a),
                  letterSpacing: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Tagline ──
          FadeTransition(
            opacity: _taglineReveal,
            child: Text(
              'Smart Bus Travel, Simplified',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 1,
              ),
            ),
          ),

          const Spacer(flex: 4),
        ],
      ),
    );
  }
}



