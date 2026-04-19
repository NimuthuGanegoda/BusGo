import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // Scene animations
  late AnimationController _cloudAnim;
  late AnimationController _busAnim;
  late AnimationController _wheelAnim;
  late AnimationController _roadAnim;
  late AnimationController _formEntrance;

  TextStyle _poppins({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  @override
  void initState() {
    super.initState();

    _cloudAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _busAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _wheelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _roadAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _formEntrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _cloudAnim.stop();
    _busAnim.stop();
    _wheelAnim.stop();
    _roadAnim.stop();
    _formEntrance.stop();
    _cloudAnim.dispose();
    _busAnim.dispose();
    _wheelAnim.dispose();
    _roadAnim.dispose();
    _formEntrance.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // ── SKY BACKGROUND ──
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF87CEEB), // Light sky blue
                  Color(0xFF5BA3D9), // Mid blue
                  Color(0xFF2E86C1), // Deeper blue
                ],
              ),
            ),
          ),

          // ── CLOUDS ──
          _buildClouds(screenW),

          // ── "Your Journey Starts Here" TEXT ──
          Positioned(
            top: screenH * 0.08,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _formEntrance,
                curve: const Interval(0, 0.5, curve: Curves.easeOut),
              ),
              child: Text(
                'Your Journey\nStarts Here',
                textAlign: TextAlign.center,
                style: _poppins(
                  size: 28,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ).copyWith(
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── HILLS (background) ──
          Positioned(
            bottom: screenH * 0.52,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(screenW, 100),
              painter: _HillsPainter(),
            ),
          ),

          // ── ROAD ──
          Positioned(
            bottom: screenH * 0.50,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _roadAnim,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(screenW, 30),
                  painter: _RoadPainter(progress: _roadAnim.value),
                );
              },
            ),
          ),

          // ── BUS ──
          Positioned(
            bottom: screenH * 0.51,
            left: screenW * 0.08,
            child: AnimatedBuilder(
              animation: Listenable.merge([_busAnim, _wheelAnim]),
              builder: (context, child) {
                final bounce = sin(_busAnim.value * pi) * 3;
                return Transform.translate(
                  offset: Offset(0, -bounce),
                  child: _buildBus(),
                );
              },
            ),
          ),

          // ── GREEN GROUND ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenH * 0.52,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF4CAF50),
                    Color(0xFF388E3C),
                    Color(0xFF2E7D32),
                  ],
                ),
              ),
            ),
          ),

          // ── GLASSMORPHISM LOGIN FORM ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _formEntrance,
                curve: const Interval(0.2, 1, curve: Curves.easeOut),
              )),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _formEntrance,
                  curve: const Interval(0.3, 1, curve: Curves.easeOut),
                ),
                child: _buildGlassForm(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUDS (floating across sky)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildClouds(double screenW) {
    return AnimatedBuilder(
      animation: _cloudAnim,
      builder: (context, child) {
        return Stack(
          children: [
            _buildCloud(
              x: ((_cloudAnim.value * screenW * 1.5) % (screenW + 120)) - 60,
              y: 60,
              scale: 1.0,
              opacity: 0.9,
            ),
            _buildCloud(
              x: (((_cloudAnim.value + 0.4) * screenW * 1.2) % (screenW + 100)) - 50,
              y: 110,
              scale: 0.7,
              opacity: 0.6,
            ),
            _buildCloud(
              x: (((_cloudAnim.value + 0.7) * screenW * 1.0) % (screenW + 80)) - 40,
              y: 40,
              scale: 0.5,
              opacity: 0.4,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCloud({
    required double x,
    required double y,
    required double scale,
    required double opacity,
  }) {
    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Transform.translate(
                offset: const Offset(-15, -10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(-25, 0),
                child: Container(
                  width: 60,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUS (simplified SVG-style bus with rotating wheels)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBus() {
    return SizedBox(
      width: 120,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bus body
          Positioned(
            bottom: 12,
            left: 0,
            child: Container(
              width: 120,
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFF6871FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4E54AA), width: 1.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  // Headlight
                  Container(
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAEE5A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Windows
                  ...List.generate(4, (i) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      width: 18,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA6C3FF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
          // Yellow stripe
          Positioned(
            bottom: 18,
            left: 2,
            child: Container(
              width: 116,
              height: 3,
              color: const Color(0xFFFAEE5A),
            ),
          ),
          // Front wheel
          Positioned(
            bottom: 2,
            left: 18,
            child: _buildWheel(),
          ),
          // Rear wheel
          Positioned(
            bottom: 2,
            left: 82,
            child: _buildWheel(),
          ),
        ],
      ),
    );
  }

  Widget _buildWheel() {
    return AnimatedBuilder(
      animation: _wheelAnim,
      builder: (context, child) {
        return Transform.rotate(
          angle: _wheelAnim.value * 2 * pi,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF666666), width: 1),
            ),
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF999999),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GLASSMORPHISM LOGIN FORM (from Codepen)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGlassForm(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Login title ──
                      Text(
                        'Login',
                        style: _poppins(
                          size: 32,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Email field (rounded pill) ──
                      _buildGlassField(
                        controller: _emailController,
                        hint: 'Email Address',
                        icon: Icons.person,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // ── Password field (rounded pill) ──
                      _buildGlassField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        obscure: true,
                        onIconTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 8) return 'Minimum 8 characters';
                          return null;
                        },
                      ),

                      // Server error
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.error_outline, size: 14, color: Color(0xFFFF6B6B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                auth.errorMessage!,
                                style: _poppins(size: 11, color: const Color(0xFFFF6B6B)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),

                      // ── Remember me + Forgot Password ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _rememberMe = !_rememberMe),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _rememberMe
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(
                                          _rememberMe ? 1.0 : 0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _rememberMe
                                      ? const Icon(Icons.check,
                                          size: 11, color: Color(0xFF0a2862))
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Remember me',
                                  style: _poppins(
                                    size: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/forgot-password'),
                            child: Text(
                              'Forgot Password?',
                              style: _poppins(
                                size: 12,
                                weight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── White Login button (rounded pill) ──
                      GestureDetector(
                        onTap: auth.isLoading
                            ? null
                            : () async {
                                auth.clearError();
                                if (!_formKey.currentState!.validate()) return;
                                final success = await auth.login(
                                  _emailController.text.trim(),
                                  _passwordController.text,
                                );
                                if (success && mounted) {
                                  // Stop all repeating animations before navigation
                                  _cloudAnim.stop();
                                  _busAnim.stop();
                                  _wheelAnim.stop();
                                  _roadAnim.stop();
                                  context.read<UserProvider>().setUser(auth.currentUser!);
                                  GoRouter.of(context).go('/home');
                                }
                              },
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: auth.isLoading
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0a2862),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Signing in...',
                                      style: _poppins(
                                        size: 16,
                                        weight: FontWeight.w600,
                                        color: const Color(0xFF0a2862),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Login',
                                  style: _poppins(
                                    size: 16,
                                    weight: FontWeight.w600,
                                    color: const Color(0xFF0a2862),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ── Social login ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Google Sign-In coming soon!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Text.rich(
                              TextSpan(children: [
                                WidgetSpan(
                                  child: Icon(Icons.g_mobiledata,
                                      size: 22, color: Colors.white.withOpacity(0.8)),
                                ),
                                TextSpan(
                                  text: ' Google',
                                  style: _poppins(
                                    size: 14,
                                    weight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Register link ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: _poppins(
                              size: 13,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/register'),
                            child: Text(
                              'Register',
                              style: _poppins(
                                size: 13,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // GLASS FIELD (rounded pill input from Codepen)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGlassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onIconTap,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure && _obscurePassword,
      keyboardType: keyboardType,
      validator: validator,
      style: _poppins(size: 15, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _poppins(size: 15, color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        suffixIcon: GestureDetector(
          onTap: onIconTap,
          child: Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Icon(icon, size: 20, color: Colors.white.withOpacity(0.7)),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.25), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.25), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.6), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
        ),
        errorStyle: _poppins(size: 11, color: const Color(0xFFFF6B6B)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HILLS PAINTER
// ═══════════════════════════════════════════════════════════════════════════════
class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Back hill (lighter)
    final backHill = Paint()..color = const Color(0xFF66BB6A);
    final backPath = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.1,
          size.width * 0.5, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.9,
          size.width, size.height * 0.3)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(backPath, backHill);

    // Front hill (darker)
    final frontHill = Paint()..color = const Color(0xFF4CAF50);
    final frontPath = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.2,
          size.width * 0.6, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.85, size.height * 1.1,
          size.width, size.height * 0.5)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(frontPath, frontHill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROAD PAINTER (with moving dashes)
// ═══════════════════════════════════════════════════════════════════════════════
class _RoadPainter extends CustomPainter {
  final double progress;
  _RoadPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Road surface
    final road = Paint()..color = const Color(0xFF555555);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      road,
    );

    // Road edges
    final edgePaint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), edgePaint);
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), edgePaint);

    // Moving dashed center line
    final dashPaint = Paint()
      ..color = const Color(0xFFFAEE5A)
      ..strokeWidth = 2;

    const dashWidth = 20.0;
    const gapWidth = 15.0;
    final totalPattern = dashWidth + gapWidth;
    final offset = progress * totalPattern;

    double x = -totalPattern + offset;
    while (x < size.width) {
      final startX = x.clamp(0.0, size.width);
      final endX = (x + dashWidth).clamp(0.0, size.width);
      if (endX > startX) {
        canvas.drawLine(
          Offset(startX, size.height / 2),
          Offset(endX, size.height / 2),
          dashPaint,
        );
      }
      x += totalPattern;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) => old.progress != progress;
}
