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

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  double _offset = 0.0;
  late ScrollController _scrollController;

  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;

  final _tokenService = ScannerTokenService();
  late final ScannerApiService _api;

  // Keep radar animation from original
  late final AnimationController _radarSweep;
  late final AnimationController _radarPulse;

  @override
  void initState() {
    super.initState();
    _api = ScannerApiService(_tokenService);

    _radarSweep = AnimationController(vsync: this,
        duration: const Duration(seconds: 3))..repeat();
    _radarPulse = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat();

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() => _offset = _scrollController.offset);
    });

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
    _scrollController.dispose();
    _radarSweep.dispose();
    _radarPulse.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleStartSession() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    const maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _api.login(_emailCtrl.text.trim(), _passCtrl.text);
        if (!mounted) return;
        _radarSweep.stop(); _radarPulse.stop();
        BusgoAlert.show(context, type: BusgoAlertType.success,
            title: 'Session Started!',
            message: 'Scanner is ready. Start scanning passengers.');
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => ScannerMainShell(api: _api)));
        return;
      } catch (e) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (msg.contains('LOGIN_RESTRICTED') || msg.contains('not authorized')) {
          if (!mounted) return;
          setState(() => _loading = false);
          BusgoAlert.show(context, type: BusgoAlertType.error,
              title: 'Access Denied',
              message: 'This account is not authorized to use this app.');
          return;
        }
        if (msg.contains('401') || msg.contains('Invalid') ||
            msg.contains('credentials') || msg.contains('password')) {

        // AFTER — add this block above the existing 401 check
        if (msg.contains('422') || msg.contains('VALIDATION_ERROR')) {
          if (!mounted) return;
          setState(() => _loading = false);
          BusgoAlert.show(context, type: BusgoAlertType.error,
              title: 'Invalid Input',
              message: 'Please enter a valid email address.');
          return;
        }


        if (msg.contains('401') || msg.contains('Invalid') ||
            msg.contains('credentials') || msg.contains('password')) {
          if (!mounted) return;
          setState(() => _loading = false);
          BusgoAlert.show(context, type: BusgoAlertType.error,
              title: 'Login Failed',
              message: 'Invalid email or password. Please try again.');
          return;
        }
        if (msg.contains('429') || msg.contains('Too many')) {
          if (!mounted) return;
          setState(() => _loading = false);
          BusgoAlert.show(context, type: BusgoAlertType.warning,
              title: 'Slow Down',
              message: 'Too many attempts. Please wait a moment.');
          return;
        }
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }
        if (!mounted) return;
        setState(() => _loading = false);
        BusgoAlert.show(context, type: BusgoAlertType.warning,
            title: 'Connection Error',
            message: 'Could not reach the server. Check your connection.');
        return;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight  = MediaQuery.of(context).size.height;
    final scrollPercent = (_offset / (screenHeight * 0.7)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF111B29),
      body: Stack(children: [

        // ── 1. FIXED PARALLAX BACKGROUND ──────────────────────────────
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1200, height: 800,
              child: Stack(children: [
                _layer('assets/images/scene/sky.jpg',     0.10),
                _layer('assets/images/scene/mountBg.png', 0.20),
                _layer('assets/images/scene/mountMg.png', 0.40),
                _layer('assets/images/scene/cloud2.png',  0.50),

                // "SCAN WITH US" fades out on scroll
                _sceneText('SCAN WITH US', Colors.white,
                  opacity: (1.0 - scrollPercent * 2.5).clamp(0.0, 1.0),
                  yOffset: -50 * scrollPercent),

                _layer('assets/images/scene/mountFg.png', 0.70),
                _layer('assets/images/scene/cloud1.png',  0.80),
                _layer('assets/images/scene/cloud3.png',  0.65),

                // Dark plug
                Transform.translate(
                  offset: Offset(0, 800 - (_offset * 0.70)),
                  child: Container(width: 1200, height: 1200,
                      color: const Color(0xFF040A14))),

                // Fog gradient
                Transform.translate(
                  offset: Offset(0, 600 - (_offset * 0.70)),
                  child: Container(
                    width: 1200, height: 220,
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [const Color(0xFF040A14).withOpacity(0),
                               const Color(0xFF040A14)]))),
                ),

                // "SCANNER" revealed through fog
                _sceneText('SCANNER', const Color(0xFF3FEFEF),
                  opacity: ((scrollPercent - 0.4) * 2.5).clamp(0.0, 1.0),
                  yOffset: 20 * (1 - scrollPercent), size: 50),

                // Radar animation (kept from original — sits in scene)
                Positioned(
                  top: 60, left: 0, right: 0,
                  child: Opacity(
                    opacity: (1.0 - scrollPercent * 2).clamp(0.0, 1.0),
                    child: Center(child: AnimatedBuilder(
                      animation: Listenable.merge([_radarSweep, _radarPulse]),
                      builder: (_, __) => CustomPaint(
                        size: const Size(200, 200),
                        painter: _RadarPainter(
                          sweepAngle:    _radarSweep.value * 2 * pi,
                          pulseProgress: _radarPulse.value,
                        )),
                    )),
                  ),
                ),

                // Down arrow
                Positioned(
                  top: 320, left: 0, right: 0,
                  child: Opacity(
                    opacity: (1.0 - scrollPercent * 3).clamp(0.0, 1.0),
                    child: const Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Scroll to Sign In', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14,
                            letterSpacing: 1.5)),
                      SizedBox(height: 8),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70, size: 36),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── 2. SCROLLABLE LOGIN CONTENT ────────────────────────────────
        SingleChildScrollView(
          controller: _scrollController,
          child: Column(children: [
            SizedBox(height: screenHeight * 0.88),

            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28)),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 1.5)),
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
                  child: Form(key: _formKey, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Handle
                    Center(child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2)))),

                    Text('Start Session', style: GoogleFonts.poppins(
                      fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Sign in to begin scanning', style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.white54)),

                    const SizedBox(height: 24),

                    // Email
                    _field(ctrl: _emailCtrl, hint: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboard: TextInputType.emailAddress),
                    const SizedBox(height: 14),

                    // Password
                    _field(ctrl: _passCtrl, hint: 'Password',
                      icon: Icons.lock_outline, obscure: _obscure,
                      suffix: _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      onSuffix: () => setState(() => _obscure = !_obscure)),

                    const SizedBox(height: 24),

                    // Start Scanning button
                    GestureDetector(
                      onTap: _loading ? null : _handleStartSession,
                      child: Container(
                        width: double.infinity, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12, offset: const Offset(0, 4))]),
                        alignment: Alignment.center,
                        child: _loading
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Color(0xFF0A1628))),
                                const SizedBox(width: 10),
                                Text('Starting session...', style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0A1628))),
                              ])
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.qr_code_scanner_rounded,
                                    size: 20, color: Color(0xFF0A1628)),
                                const SizedBox(width: 8),
                                Text('Start Scanning', style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0A1628))),
                              ]),
                      ),
                    ),
                  ])),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }


  Widget _layer(String asset, double speed) => Transform.translate(
    offset: Offset(0, -(_offset * speed)),
    child: Image.asset(asset, width: 1200, height: 800,
        fit: BoxFit.cover, gaplessPlayback: true));

  Widget _sceneText(String text, Color color,
      {required double opacity, required double yOffset, double size = 42}) {
    return Center(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, yOffset),
          child: Text(text,
            style: GoogleFonts.montserrat(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              shadows: const [
                Shadow(color: Color(0x44000000),
                    blurRadius: 12, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    IconData? suffix,
    VoidCallback? onSuffix,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure && _obscure,
      keyboardType: keyboard,
      style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
            fontSize: 13, color: Colors.white.withOpacity(0.35)),
        filled: true,
        fillColor: Colors.transparent,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        suffixIcon: suffix != null
            ? GestureDetector(
                onTap: onSuffix,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(suffix, size: 18,
                      color: Colors.white.withOpacity(0.5)),
                ),
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.2), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
              color: const Color(0xFF3FEFEF).withOpacity(0.6), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
        ),
        errorStyle: GoogleFonts.poppins(
            fontSize: 11, color: const Color(0xFFFF9999)),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'This field is required';
        if (obscure && v.length < 6) return 'Minimum 6 characters';
        return null;
      },
    );
  }
}

// Radar painter
class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseProgress;
  _RadarPainter({required this.sweepAngle, required this.pulseProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center    = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 1; i <= 4; i++) {
      final r       = maxRadius * (i / 4);
      final opacity = 0.08 + (i == 4 ? pulseProgress * 0.06 : 0);
      canvas.drawCircle(center, r, Paint()
        ..color = const Color(0xFF3FEFEF).withOpacity(opacity)
        ..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    final crossPaint = Paint()
      ..color = const Color(0xFF3FEFEF).withOpacity(0.05)..strokeWidth = 0.5;
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius),
        Offset(center.dx, center.dy + maxRadius), crossPaint);
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy),
        Offset(center.dx + maxRadius, center.dy), crossPaint);

    canvas.drawCircle(center, maxRadius, Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 0.8, endAngle: sweepAngle,
        colors: [Colors.transparent,
                 const Color(0xFF3FEFEF).withOpacity(0.25)],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill);

    final lineEnd = Offset(center.dx + maxRadius * cos(sweepAngle),
                           center.dy + maxRadius * sin(sweepAngle));
    canvas.drawLine(center, lineEnd, Paint()
      ..color = const Color(0xFF3FEFEF).withOpacity(0.5)..strokeWidth = 1.5);

    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF3FEFEF));
    canvas.drawCircle(center, 8, Paint()
      ..color = const Color(0xFF3FEFEF).withOpacity(0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 1);

    final rng = Random(42);
    for (int i = 0; i < 6; i++) {
      final angle      = rng.nextDouble() * 2 * pi;
      final dist       = maxRadius * (0.2 + rng.nextDouble() * 0.7);
      final blipCenter = Offset(center.dx + dist * cos(angle),
                                center.dy + dist * sin(angle));
      final angleDiff  = ((sweepAngle % (2 * pi)) - angle).abs();
      final visibility = angleDiff < 1.0 ? (1.0 - angleDiff) * 0.8 : 0.0;
      if (visibility > 0.05) canvas.drawCircle(blipCenter, 3, Paint()
        ..color = const Color(0xFF3FEFEF).withOpacity(visibility));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.sweepAngle != sweepAngle || old.pulseProgress != pulseProgress;
}



