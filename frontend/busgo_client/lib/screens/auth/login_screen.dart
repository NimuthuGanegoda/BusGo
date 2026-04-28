import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/busgo_alert.dart';

// ── Rain drop data ────────────────────────────────────────────────────────────
class _Drop {
  final double x;       // 0.0–1.0
  final double phase;   // starting offset
  final double speed;
  final double len;
  final double opacity;
  const _Drop(this.x, this.phase, this.speed, this.len, this.opacity);
}

// ═════════════════════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  // Rain
  late AnimationController _rainCtrl;
  // Totoro bounce when tapped
  late AnimationController _bounceCtrl;
  late Animation<double>   _bounceAnim;
  // Scene fade-in
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  // Rain intensity toggle
  bool _raining = true;

  static final List<_Drop> _drops = _generateDrops();

  static List<_Drop> _generateDrops() {
    final rng  = Random(77);
    final list = <_Drop>[];
    for (int i = 0; i < 90; i++) {
      list.add(_Drop(
        rng.nextDouble(),
        rng.nextDouble(),
        0.25 + rng.nextDouble() * 0.55,
        0.04 + rng.nextDouble() * 0.05,
        0.25 + rng.nextDouble() * 0.45,
      ));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();

    _rainCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))..repeat();

    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -28), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -28, end: 0),  weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0, end: -12),  weight: 15),
      TweenSequenceItem(tween: Tween(begin: -12, end: 0),  weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0, end: 0),    weight: 25),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _rainCtrl.dispose();
    _bounceCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // Totoro tapped: bounce then show login sheet
  void _onTotoroTap() async {
    setState(() => _raining = true);
    await _bounceCtrl.forward(from: 0);
    if (!mounted) return;
    _showLoginSheet();
  }

  void _showLoginSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (_) => _LoginSheet(
        onLoginSuccess: (user) {
          context.read<UserProvider>().setUser(user);
          GoRouter.of(context).go('/home');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(children: [

          // ── Dark background ────────────────────────────────────────────────
          Container(color: Colors.black),

          // ── Moon ──────────────────────────────────────────────────────────
          Positioned(
            top: size.height * 0.07,
            right: size.width * 0.18,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF5EBC8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF5EBC8).withOpacity(0.35),
                    blurRadius: 40, spreadRadius: 12),
                ],
              ),
            ),
          ),

          // ── Stars ─────────────────────────────────────────────────────────
          CustomPaint(
            size: size,
            painter: _StarsPainter(),
          ),

          // ── Rain ──────────────────────────────────────────────────────────
          if (_raining)
            AnimatedBuilder(
              animation: _rainCtrl,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _RainPainter(_drops, _rainCtrl.value),
              ),
            ),

          // ── Forest glow circle (bus stop ground) ───────────────────────────
          Positioned(
            bottom: -size.height * 0.15,
            left: size.width * 0.5 - size.height * 0.45,
            child: Container(
              width:  size.height * 0.9,
              height: size.height * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A3A1A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.95),
                    blurRadius: 60,
                    spreadRadius: 80,
                  ),
                  BoxShadow(
                    color: const Color(0xFF0D2A10).withOpacity(0.7),
                    blurRadius: 30,
                    spreadRadius: -10,
                  ),
                ],
              ),
            ),
          ),

          // ── Floor strip ───────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: size.height * 0.12,
            child: Container(color: const Color(0xFF1A271A)),
          ),

          // ── Bus stop sign ─────────────────────────────────────────────────
          Positioned(
            bottom: size.height * 0.12,
            right: size.width * 0.14,
            child: _BusStopSign(),
          ),

          // ── Two girls silhouette ───────────────────────────────────────────
          Positioned(
            bottom: size.height * 0.12,
            right: size.width * 0.08,
            child: CustomPaint(
              size: const Size(60, 80),
              painter: _GirlsPainter(),
            ),
          ),

          // ── Totoro (tappable) ──────────────────────────────────────────────
          Positioned(
            bottom: size.height * 0.11,
            left: size.width * 0.5 - 70,
            child: GestureDetector(
              onTap: _onTotoroTap,
              child: AnimatedBuilder(
                animation: _bounceAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _bounceAnim.value),
                  child: child,
                ),
                child: CustomPaint(
                  size: const Size(140, 160),
                  painter: _TotoroPainter(),
                ),
              ),
            ),
          ),

          // ── Tap hint ──────────────────────────────────────────────────────
          Positioned(
            bottom: size.height * 0.30,
            left: 0, right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _bounceCtrl,
                builder: (_, __) => Opacity(
                  opacity: _bounceCtrl.isAnimating ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text('Tap Totoro to board',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white38,
                          letterSpacing: 1.2)),
                  ),
                ),
              ),
            ),
          ),

          // ── Title top ─────────────────────────────────────────────────────
          Positioned(
            top: size.height * 0.05,
            left: 0, right: 0,
            child: Column(children: [
              Text('BUSGO',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 8,
                  shadows: [Shadow(
                      color: Colors.white.withOpacity(0.25),
                      blurRadius: 20)],
                )),
              Text('Your journey starts here',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white30,
                    letterSpacing: 2)),
            ]),
          ),

          // ── Bottom buttons ─────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [

                  // Login button
                  GestureDetector(
                    onTap: _showLoginSheet,
                    child: Container(
                      width: double.infinity, height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(
                            color: const Color(0xFF2E7D32).withOpacity(0.5),
                            blurRadius: 18, offset: const Offset(0, 6))],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.login_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('Begin Journey',
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Register link
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("Don't have an account? ",
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.white24)),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: Text('Register',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LOGIN BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _LoginSheet extends StatefulWidget {
  final void Function(dynamic user) onLoginSuccess;
  const _LoginSheet({required this.onLoginSuccess});

  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  final _formKey           = GlobalKey<FormState>();
  final _emailController   = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  TextStyle _poppins({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
  }) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

  Future<void> _handleLogin() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    if (!_formKey.currentState!.validate()) return;

    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      widget.onLoginSuccess(auth.currentUser!);
    } else {
      final error = auth.errorMessage ?? '';
      String title  = 'Login Failed';
      String message = 'Something went wrong. Please try again.';

      if (error == 'LOGIN_RESTRICTED') {
        title   = 'Access Denied';
        message = 'This account is not authorized to use this app.';
      } else if (error.contains('EMAIL_NOT_VERIFIED') ||
                 error.contains('verify your email')) {
        title   = 'Email Not Verified';
        message = 'Please verify your email first.';
      } else if (error.contains('invalid') ||
                 error.contains('credentials') ||
                 error.contains('401')) {
        message = 'Invalid email or password.';
      } else if (error == 'ACCOUNT_LOCKED') {
        title   = 'Account Locked';
        message = 'Too many attempts. Try again in 15 minutes.';
      } else if (error.contains('socket') ||
                 error.contains('connection') ||
                 error.contains('timeout')) {
        title   = 'Connection Error';
        message = 'Could not reach the server.';
      } else if (error.isNotEmpty) {
        message = error;
      }

      BusgoAlert.show(context,
          type: BusgoAlertType.error,
          title: title,
          message: message);
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F0E).withOpacity(0.92),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28)),
              border: Border.all(color: Colors.white10, width: 1.5),
            ),
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return Form(
                  key: _formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [

                    // Handle
                    Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2))),

                    // Logo
                    Text('BUSGO',
                      style: _poppins(
                          size: 22,
                          weight: FontWeight.w800,
                          color: const Color(0xFF81C784))
                          .copyWith(letterSpacing: 4)),
                    const SizedBox(height: 4),
                    Text('Welcome back',
                      style: _poppins(size: 12, color: Colors.white38)),
                    const SizedBox(height: 24),

                    // Email
                    _buildField(
                      controller: _emailController,
                      hint: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Email is required';
                        final rx = RegExp(
                            r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                        if (!rx.hasMatch(v.trim()))
                          return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Password
                    _buildField(
                      controller: _passwordController,
                      hint: 'Password',
                      icon: _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      obscure: _obscurePassword,
                      onIconTap: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 8) return 'Minimum 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/forgot-password');
                        },
                        child: Text('Forgot Password?',
                          style: _poppins(
                              size: 12,
                              color: const Color(0xFF81C784))),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Login button
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          disabledBackgroundColor: Colors.green.withOpacity(0.3),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28)),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Login',
                                style: _poppins(
                                    size: 15, weight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Register
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text("Don't have an account? ",
                        style: _poppins(size: 12, color: Colors.white30)),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/register');
                        },
                        child: Text('Register',
                          style: _poppins(
                              size: 12,
                              weight: FontWeight.w600,
                              color: const Color(0xFF81C784))),
                      ),
                    ]),
                  ]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onIconTap,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      obscureText:  obscure,
      keyboardType: keyboard,
      validator:    validator,
      style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: GoogleFonts.poppins(
            fontSize: 14, color: Colors.white30),
        filled:    true,
        fillColor: Colors.white.withOpacity(0.07),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 15),
        suffixIcon: GestureDetector(
          onTap: onIconTap,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(icon, size: 20, color: Colors.white38),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(
            minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
                color: Colors.white.withOpacity(0.15))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
                color: Colors.white.withOpacity(0.15))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(
                color: Color(0xFF4CAF50), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(
                color: Color(0xFFEF5350))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(
                color: Color(0xFFEF5350))),
        errorStyle: GoogleFonts.poppins(
            fontSize: 11, color: const Color(0xFFEF9A9A)),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PAINTERS
// ═════════════════════════════════════════════════════════════════════════════

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final rng   = Random(13);
    for (int i = 0; i < 60; i++) {
      final x  = rng.nextDouble() * size.width;
      final y  = rng.nextDouble() * size.height * 0.55;
      final r  = 0.5 + rng.nextDouble() * 1.2;
      final op = 0.3 + rng.nextDouble() * 0.6;
      canvas.drawCircle(Offset(x, y), r, paint..color = Colors.white.withOpacity(op));
    }
  }
  @override
  bool shouldRepaint(_StarsPainter old) => false;
}

class _RainPainter extends CustomPainter {
  final List<_Drop> drops;
  final double progress;
  _RainPainter(this.drops, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    for (final d in drops) {
      final t  = (d.phase + progress * d.speed) % 1.0;
      final x  = d.x * size.width + t * size.height * 0.18;
      final y  = t * (size.height + 60) - 30;
      final dx = d.len * size.width * 0.12;
      final dy = d.len * size.height * 0.55;
      paint.color = const Color(0xFFB3D9FF).withOpacity(d.opacity * 0.55);
      canvas.drawLine(Offset(x, y), Offset(x + dx, y + dy), paint);
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => old.progress != progress;
}

// ── Bus Stop Sign ─────────────────────────────────────────────────────────────
class _BusStopSign extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70, height: 130,
      child: Stack(children: [
        // Pole
        Positioned(
          left: 32, top: 30,
          child: Container(
            width: 5, height: 100,
            color: const Color(0xFF5D4037),
          ),
        ),
        // Sign board
        Positioned(
          left: 0, top: 0,
          child: Container(
            width: 70, height: 35,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A5C),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            alignment: Alignment.center,
            child: Text('BUS\nSTOP',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.3,
                  letterSpacing: 1.5)),
          ),
        ),
      ]),
    );
  }
}

// ── Girls silhouette ──────────────────────────────────────────────────────────
class _GirlsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0xFF0D1F0D);

    // Big girl (Satsuki)
    canvas.drawOval(Rect.fromLTWH(5, 5, 18, 18), dark); // head
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 22, 22, 30), const Radius.circular(4)), dark); // body
    // dress
    final path = Path()
      ..moveTo(3, 42)
      ..lineTo(-2, 70)
      ..lineTo(28, 70)
      ..lineTo(25, 42)
      ..close();
    canvas.drawPath(path, dark);

    // Small girl (Mei)
    canvas.drawOval(Rect.fromLTWH(28, 18, 14, 14), dark); // head
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(26, 31, 18, 22), const Radius.circular(3)), dark);
    final path2 = Path()
      ..moveTo(26, 48)
      ..lineTo(22, 70)
      ..lineTo(46, 70)
      ..lineTo(44, 48)
      ..close();
    canvas.drawPath(path2, dark);

    // Umbrellas (simplified)
    final umbPaint = Paint()
      ..color = const Color(0xFF1A3A1A)
      ..style  = PaintingStyle.fill;
    // Big umbrella
    canvas.drawPath(
      Path()
        ..moveTo(-10, 10)
        ..quadraticBezierTo(14, -8, 38, 10)
        ..quadraticBezierTo(14, 2, -10, 10)
        ..close(),
      umbPaint,
    );
    // Small umbrella
    canvas.drawPath(
      Path()
        ..moveTo(20, 22)
        ..quadraticBezierTo(35, 10, 52, 22)
        ..quadraticBezierTo(35, 16, 20, 22)
        ..close(),
      umbPaint,
    );
  }

  @override
  bool shouldRepaint(_GirlsPainter old) => false;
}

// ── Totoro Painter ────────────────────────────────────────────────────────────
class _TotoroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size sz) {
    final cx = sz.width  / 2;
    final cy = sz.height * 0.54;

    // ─ Body ─
    final bodyPaint = Paint()..color = const Color(0xFF2D2D3C);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy),
            width: sz.width * 0.82, height: sz.height * 0.72),
        bodyPaint);

    // ─ Ears ─
    _drawEar(canvas, cx - 24, cy - sz.height * 0.28,
        cx - 40, cy - sz.height * 0.50, cx - 10, bodyPaint);
    _drawEar(canvas, cx + 24, cy - sz.height * 0.28,
        cx + 40, cy - sz.height * 0.50, cx + 10, bodyPaint);

    // ─ Inner ear pink ─
    final innerEarPaint = Paint()..color = const Color(0xFF5A3A4A);
    _drawEar(canvas, cx - 22, cy - sz.height * 0.29,
        cx - 36, cy - sz.height * 0.46, cx - 12, innerEarPaint,
        scale: 0.6);
    _drawEar(canvas, cx + 22, cy - sz.height * 0.29,
        cx + 36, cy - sz.height * 0.46, cx + 12, innerEarPaint,
        scale: 0.6);

    // ─ Belly ─
    final bellyPaint = Paint()..color = const Color(0xFFDDD8BC);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 4, cy + 8),
            width: sz.width * 0.5, height: sz.height * 0.46),
        bellyPaint);

    // ─ Belly stripe pattern (dark chevrons) ─
    final chevPaint = Paint()
      ..color      = const Color(0xFF2D2D3C)
      ..strokeWidth = 2.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final y = cy + 4 + i * 14.0;
      final w = 18.0 - i * 4;
      canvas.drawPath(
        Path()
          ..moveTo(cx - w, y)
          ..quadraticBezierTo(cx + 4, y - 9, cx + 4 + w, y),
        chevPaint,
      );
    }

    // ─ Nature marks (green spirit dots) ─
    final dotPaint = Paint()..color = const Color(0xFF2E5C28);
    for (final pos in [
      [cx - 18.0, cy - 12.0, 6.0],
      [cx + 26.0, cy - 8.0,  5.0],
      [cx + 22.0, cy - 22.0, 4.0],
      [cx - 10.0, cy + 28.0, 4.0],
      [cx + 35.0, cy + 20.0, 3.5],
    ]) {
      canvas.drawCircle(Offset(pos[0], pos[1]), pos[2], dotPaint);
    }

    // ─ Eyes white ─
    final eyeWhite = Paint()..color = Colors.white;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 18, cy - sz.height * 0.12),
            width: 24, height: 28),
        eyeWhite);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 18, cy - sz.height * 0.12),
            width: 24, height: 28),
        eyeWhite);

    // ─ Pupils ─
    final pupil = Paint()..color = const Color(0xFF18181E);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 16, cy - sz.height * 0.10),
            width: 15, height: 19),
        pupil);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 20, cy - sz.height * 0.10),
            width: 15, height: 19),
        pupil);

    // ─ Eye shine ─
    final shine = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - 12, cy - sz.height * 0.13), 4, shine);
    canvas.drawCircle(Offset(cx + 24, cy - sz.height * 0.13), 4, shine);

    // ─ Nose ─
    final nose = Paint()..color = const Color(0xFF1A0A20);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 3, cy + 2), width: 9, height: 5),
        nose);

    // ─ Whiskers ─
    final w = Paint()
      ..color      = Colors.white30
      ..strokeWidth = 1.3;
    canvas.drawLine(Offset(cx - 38, cy + 6),  Offset(cx - 8, cy + 5),  w);
    canvas.drawLine(Offset(cx - 38, cy + 14), Offset(cx - 8, cy + 13), w);
    canvas.drawLine(Offset(cx + 10, cy + 5),  Offset(cx + 40, cy + 6),  w);
    canvas.drawLine(Offset(cx + 10, cy + 13), Offset(cx + 40, cy + 14), w);

    // ─ Umbrella leaf (stem) ─
    final stemPaint = Paint()
      ..color      = const Color(0xFF4E3415)
      ..strokeWidth = 3
      ..strokeCap   = StrokeCap.round;
    canvas.drawLine(
        Offset(cx + 18, cy - sz.height * 0.28),
        Offset(cx + 30, cy - sz.height * 0.56),
        stemPaint);

    // ─ Leaf ─
    final leafPaint = Paint()..color = const Color(0xFF2E7D32);
    final leaf = Path()
      ..moveTo(cx,      cy - sz.height * 0.54)
      ..quadraticBezierTo(cx + 18, cy - sz.height * 0.76, cx + 56, cy - sz.height * 0.54)
      ..quadraticBezierTo(cx + 18, cy - sz.height * 0.42, cx,      cy - sz.height * 0.54)
      ..close();
    canvas.drawPath(leaf, leafPaint);
    // leaf highlight
    canvas.drawPath(leaf,
        Paint()
          ..color   = const Color(0xFF1B5E20).withOpacity(0.4)
          ..style   = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // vein
    final veinP = Paint()
      ..color      = const Color(0xFF1B5E20).withOpacity(0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(cx + 28, cy - sz.height * 0.54),
        Offset(cx + 28, cy - sz.height * 0.70),
        veinP);
    for (int i = 0; i < 3; i++) {
      final y2 = cy - sz.height * (0.56 + i * 0.04);
      canvas.drawLine(Offset(cx + 28, y2), Offset(cx + 28 + 10, y2 - 6), veinP);
      canvas.drawLine(Offset(cx + 28, y2), Offset(cx + 28 - 8, y2 - 5), veinP);
    }

    // ─ Feet ─
    final feetPaint = Paint()..color = const Color(0xFF23232F);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 22, cy + sz.height * 0.35),
            width: 32, height: 14),
        feetPaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 24, cy + sz.height * 0.35),
            width: 32, height: 14),
        feetPaint);

    // ─ Claws ─
    final claw = Paint()
      ..color      = const Color(0xFF18181E)
      ..strokeWidth = 1.8;
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
          Offset(cx - 30 + i * 7.0, cy + sz.height * 0.37),
          Offset(cx - 32 + i * 7.0, cy + sz.height * 0.43), claw);
      canvas.drawLine(
          Offset(cx + 14 + i * 7.0, cy + sz.height * 0.37),
          Offset(cx + 12 + i * 7.0, cy + sz.height * 0.43), claw);
    }
  }

  void _drawEar(Canvas canvas, double tx, double ty, double tipX, double tipY,
      double bx, Paint paint, {double scale = 1.0}) {
    final path = Path()
      ..moveTo(tx, ty)
      ..lineTo(tipX, tipY)
      ..lineTo(bx,  ty)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TotoroPainter old) => false;
}



