import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/scanner_api_service.dart';
import '../widgets/busgo_alert.dart';
import 'scanner_main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  final _tokenService = ScannerTokenService();
  late final ScannerApiService _api;

  late final AnimationController _radarSweep;
  late final AnimationController _radarPulse;
  late final AnimationController _formEntrance;

  @override
  void initState() {
    super.initState();
    _api = ScannerApiService(_tokenService);

    _radarSweep = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _radarPulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _formEntrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();

    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    if (await _tokenService.hasSession()) {
      try {
        if (!mounted) return;
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ScannerMainShell(api: _api)));
      } catch (_) {
        await _tokenService.clear();
      }
    }
  }

  @override
  void dispose() {
    _radarSweep.dispose();
    _radarPulse.dispose();
    _formEntrance.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleStartSession() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // Retry logic: try up to 2 times on network failure
    const maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _api.login(_emailCtrl.text.trim(), _passCtrl.text);
        if (!mounted) return;
        _radarSweep.stop();
        _radarPulse.stop();

        BusgoAlert.show(context,
          type: BusgoAlertType.success,
          title: 'Session Started!',
          message: 'Scanner is ready. Start scanning passengers.',
        );

        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ScannerMainShell(api: _api)));
        return;

      } catch (e) {
        final msg = e.toString().replaceFirst('Exception: ', '');

        // Check if it's a role restriction error
        if (msg.contains('LOGIN_RESTRICTED') || msg.contains('not authorized')) {
          if (!mounted) return;
          setState(() => _loading = false);
          BusgoAlert.show(context,
            type: BusgoAlertType.error,
            title: 'Access Denied',
            message: 'This account is not authorized to use this app.',
          );
          return;
        }

        // Check for 401 / credential errors
        if (msg.contains('401') || msg.contains('Invalid') ||
            msg.contains('credentials') || msg.contains('password')) {
          if (!mounted) return;
          setState(() => _loading = false);
          BusgoAlert.show(context,
            type: BusgoAlertType.error,
            title: 'Login Failed',
            message: 'Invalid email or password. Please try again.',
          );
          return;
        }

        // Check for rate limiting
        if (msg.contains('429') || msg.contains('Too many')) {
          if (!mounted) return;
          setState(() => _loading = false);
          BusgoAlert.show(context,
            type: BusgoAlertType.warning,
            title: 'Slow Down',
            message: 'Too many attempts. Please wait a moment and try again.',
          );
          return;
        }

        // Network error — retry on first attempt
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }

        // Last attempt failed — show connection error
        if (!mounted) return;
        setState(() => _loading = false);
        BusgoAlert.show(context,
          type: BusgoAlertType.warning,
          title: 'Connection Error',
          message: 'Could not reach the server. Check your connection.',
        );
        return;
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  TextStyle _poppins({double size = 14, FontWeight weight = FontWeight.w400, Color color = Colors.white}) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3), radius: 1.2,
              colors: [Color(0xFF0A1628), Color(0xFF040A14), Color(0xFF000000)],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.05,
          left: 0, right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_radarSweep, _radarPulse]),
              builder: (context, _) => CustomPaint(
                size: const Size(300, 300),
                painter: _RadarPainter(
                  sweepAngle: _radarSweep.value * 2 * pi,
                  pulseProgress: _radarPulse.value,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(CurvedAnimation(parent: _formEntrance, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic))),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _formEntrance, curve: const Interval(0.3, 1, curve: Curves.easeOut)),
              child: _buildGlassForm(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildGlassForm() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
        child: Container(
          padding: const EdgeInsets.fromLTRB(30, 28, 30, 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Start Session', style: _poppins(size: 32, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Sign in to begin scanning', style: _poppins(size: 13, color: Colors.white54)),
              const SizedBox(height: 24),

              _buildPillField(controller: _emailCtrl, hint: 'Email Address', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 18),

              _buildPillField(controller: _passCtrl, hint: 'Password',
                icon: _obscure ? Icons.visibility_off : Icons.visibility,
                obscure: true, onIconTap: () => setState(() => _obscure = !_obscure)),
              const SizedBox(height: 24),

              GestureDetector(
                onTap: _loading ? null : _handleStartSession,
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  alignment: Alignment.center,
                  child: _loading
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A1628))),
                        const SizedBox(width: 10),
                        Text('Starting session...', style: _poppins(size: 15, weight: FontWeight.w600, color: const Color(0xFF0A1628))),
                      ])
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF0A1628)),
                        const SizedBox(width: 8),
                        Text('Start Scanning', style: _poppins(size: 15, weight: FontWeight.w600, color: const Color(0xFF0A1628))),
                      ]),
                ),
              ),
              const SizedBox(height: 16),
              Text('Forgot password? Contact admin', style: _poppins(size: 13, color: const Color(0xFF3FEFEF), weight: FontWeight.w500)),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
            ])),
          ),
        ),
      ),
    );
  }

  Widget _buildPillField({
    required TextEditingController controller, required String hint, required IconData icon,
    bool obscure = false, VoidCallback? onIconTap, TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller, obscureText: obscure && _obscure, keyboardType: keyboardType,
      style: _poppins(size: 15, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint, hintStyle: _poppins(size: 15, color: Colors.white.withOpacity(0.4)),
        filled: true, fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        suffixIcon: GestureDetector(onTap: onIconTap, child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(icon, size: 18, color: Colors.white.withOpacity(0.5)))),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: const Color(0xFF3FEFEF).withOpacity(0.6), width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2)),
        errorStyle: _poppins(size: 11, color: const Color(0xFFFF6B6B)),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'This field is required';
        if (obscure && v.length < 6) return 'Minimum 6 characters';
        return null;
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseProgress;
  _RadarPainter({required this.sweepAngle, required this.pulseProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 1; i <= 4; i++) {
      final r = maxRadius * (i / 4);
      final opacity = 0.08 + (i == 4 ? pulseProgress * 0.06 : 0);
      canvas.drawCircle(center, r, Paint()
        ..color = const Color(0xFF3FEFEF).withOpacity(opacity)
        ..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    final crossPaint = Paint()..color = const Color(0xFF3FEFEF).withOpacity(0.05)..strokeWidth = 0.5;
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), crossPaint);
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), crossPaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(startAngle: sweepAngle - 0.8, endAngle: sweepAngle,
        colors: [Colors.transparent, const Color(0xFF3FEFEF).withOpacity(0.25)],
        transform: const GradientRotation(0),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, sweepPaint);

    final lineEnd = Offset(center.dx + maxRadius * cos(sweepAngle), center.dy + maxRadius * sin(sweepAngle));
    canvas.drawLine(center, lineEnd, Paint()..color = const Color(0xFF3FEFEF).withOpacity(0.5)..strokeWidth = 1.5);

    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF3FEFEF));
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF3FEFEF).withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 1);

    final rng = Random(42);
    for (int i = 0; i < 6; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist = maxRadius * (0.2 + rng.nextDouble() * 0.7);
      final blipCenter = Offset(center.dx + dist * cos(angle), center.dy + dist * sin(angle));
      final angleDiff = ((sweepAngle % (2 * pi)) - angle).abs();
      final visibility = angleDiff < 1.0 ? (1.0 - angleDiff) * 0.8 : 0.0;
      if (visibility > 0.05) canvas.drawCircle(blipCenter, 3, Paint()..color = const Color(0xFF3FEFEF).withOpacity(visibility));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.sweepAngle != sweepAngle || old.pulseProgress != pulseProgress;
}


