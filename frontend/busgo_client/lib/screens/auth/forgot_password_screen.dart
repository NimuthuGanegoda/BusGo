import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/busgo_alert.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {

  // Step driven by auth_provider.forgotPasswordStep (0=email,1=pin,2=new pass)
  final _emailCtrl   = TextEditingController();
  final _pinCtrl     = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  late AnimationController _enterCtrl;

  static const _bg   = Color(0xFF040D18);
  static const _teal = Color(0xFF4ECDC4);
  static const _panel= Color(0xFF0A1628);

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..forward();
    // Reset provider state when entering screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().resetForgotPassword();
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _emailCtrl.dispose(); _pinCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  // Current UI step based on provider state
  int _uiStep(AuthProvider auth) => auth.forgotPasswordStep + 1; // 0→1, 1→2, 2→3

  Future<void> _sendPin(AuthProvider auth) async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      BusgoAlert.show(context, type: BusgoAlertType.error,
          title: 'Email Required', message: 'Please enter your email address.');
      return;
    }
    await auth.sendResetPin(email);
    if (!mounted) return;
    if (auth.errorMessage != null) {
      BusgoAlert.show(context, type: BusgoAlertType.error,
          title: 'Failed', message: auth.errorMessage!);
      auth.clearError();
    }
  }

  Future<void> _verifyPin(AuthProvider auth) async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      BusgoAlert.show(context, type: BusgoAlertType.error,
          title: 'PIN Required', message: 'Enter the PIN sent to your email.');
      return;
    }
    await auth.verifyPin(pin);
    if (!mounted) return;
    if (auth.errorMessage != null) {
      BusgoAlert.show(context, type: BusgoAlertType.error,
          title: 'Invalid PIN', message: 'The PIN is incorrect or expired.');
      auth.clearError();
    }
  }

  Future<void> _resetPassword(AuthProvider auth) async {
    final ok = await auth.resetPassword(_passCtrl.text, _confirmCtrl.text);
    if (!mounted) return;
    if (ok) {
      BusgoAlert.show(context, type: BusgoAlertType.success,
          title: 'Password Reset!',
          message: 'You can now sign in with your new password.');
      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      context.go('/login');
    } else if (auth.errorMessage != null) {
      BusgoAlert.show(context, type: BusgoAlertType.error,
          title: 'Reset Failed', message: auth.errorMessage!);
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
        child: Consumer<AuthProvider>(builder: (ctx, auth, _) {
          final step = _uiStep(auth);
          return Stack(children: [
            Container(decoration: const BoxDecoration(gradient: RadialGradient(
              center: Alignment(0.0, -0.6), radius: 1.1,
              colors: [Color(0xFF0A1E30), Color(0xFF040D18)]))),
            CustomPaint(size: size, painter: _GridPainter()),
            Positioned(top: -30, left: 0, right: 0, child: Center(child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _teal.withOpacity(0.06), Colors.transparent]))))),
            SafeArea(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(children: [
                // Header
                Row(children: [
                  GestureDetector(onTap: () => context.pop(),
                    child: Container(width: 38, height: 38,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _panel,
                        border: Border.all(color: _teal.withOpacity(0.2))),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: Colors.white70))),
                  const SizedBox(width: 14),
                  Text('BUSGO', style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 4)),
                ]),
                const SizedBox(height: 32),
                // Icon
                AnimatedSwitcher(duration: const Duration(milliseconds: 300),
                  child: Container(key: ValueKey(step),
                    width: 64, height: 64,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: _panel,
                      border: Border.all(color: _teal.withOpacity(0.25), width: 1.5),
                      boxShadow: [BoxShadow(color: _teal.withOpacity(0.10),
                          blurRadius: 20, spreadRadius: 3)]),
                    child: Icon(_icon(step), size: 28, color: _teal))),
                const SizedBox(height: 16),
                Text(_title(step), style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Text(_subtitle(step), style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFF6B7A8D)),
                  textAlign: TextAlign.center),
                const SizedBox(height: 26),
                // Step dots
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _dot(1, step), _line(), _dot(2, step), _line(), _dot(3, step),
                ]),
                const SizedBox(height: 26),
                // Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _panel.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _teal.withOpacity(0.12))),
                  padding: const EdgeInsets.all(20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.12, 0), end: Offset.zero).animate(anim),
                      child: FadeTransition(opacity: anim, child: child)),
                    child: _buildStep(step, auth))),
                const SizedBox(height: 20),
                GestureDetector(onTap: () => context.go('/login'),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.arrow_back_rounded, size: 14,
                        color: _teal.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Text('Back to Login', style: GoogleFonts.poppins(
                        fontSize: 13, color: _teal.withOpacity(0.6),
                        fontWeight: FontWeight.w500)),
                  ])),
              ]))),
          ]);
        }),
      ),
    );
  }

  IconData _icon(int s) => s == 1 ? Icons.lock_reset_rounded
      : s == 2 ? Icons.pin_outlined : Icons.lock_open_rounded;
  String _title(int s) => s == 1 ? 'Reset Password'
      : s == 2 ? 'Enter PIN' : 'New Password';
  String _subtitle(int s) => s == 1
      ? 'Enter your email to receive\na reset PIN'
      : s == 2 ? 'Check your inbox and enter\nthe 6-digit PIN'
      : 'Choose a strong new password\nfor your account';

  Widget _dot(int n, int step) {
    final active = n == step; final done = n < step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active?34:28, height: active?34:28,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: done?_teal: active?_teal.withOpacity(0.12):Colors.white.withOpacity(0.05),
        border: Border.all(color: (active||done)?_teal:Colors.white.withOpacity(0.12),
            width: active?2:1.5)),
      child: Center(child: done
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : Text('$n', style: GoogleFonts.poppins(fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active?_teal:Colors.white.withOpacity(0.3)))));
  }

  Widget _line() => Container(width: 40, height: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withOpacity(0.08));

  Widget _buildStep(int step, AuthProvider auth) => switch(step) {
    1 => _step1(auth, key: const ValueKey(1)),
    2 => _step2(auth, key: const ValueKey(2)),
    _ => _step3(auth, key: const ValueKey(3)),
  };

  Widget _step1(AuthProvider auth, {Key? key}) =>
    Column(key: key, mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl('EMAIL ADDRESS'),
      _inp(_emailCtrl, 'your@email.com', Icons.email_outlined,
          keyboard: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _btn('Send Reset PIN', auth, () => _sendPin(auth)),
    ]);

  Widget _step2(AuthProvider auth, {Key? key}) =>
    Column(key: key, mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _teal.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _teal.withOpacity(0.2))),
        child: Row(children: [
          Icon(Icons.mail_outline_rounded, size: 16, color: _teal.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(child: Text('PIN sent to ${auth.forgotEmail}',
            style: GoogleFonts.poppins(fontSize: 11, color: _teal.withOpacity(0.8)))),
        ])),
      const SizedBox(height: 14),
      _lbl('6-DIGIT PIN'),
      _inp(_pinCtrl, '• • • • • •', Icons.pin_outlined,
          keyboard: TextInputType.number, maxLen: 6, center: true),
      const SizedBox(height: 16),
      _btn('Verify PIN', auth, () => _verifyPin(auth)),
      const SizedBox(height: 10),
      Center(child: GestureDetector(onTap: () => _sendPin(auth),
        child: Text("Didn't receive? Resend",
          style: GoogleFonts.poppins(fontSize: 12, color: _teal.withOpacity(0.6))))),
    ]);

  Widget _step3(AuthProvider auth, {Key? key}) =>
    Column(key: key, mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl('NEW PASSWORD'),
      _inp(_passCtrl, 'Min. 8 characters', Icons.lock_outline_rounded,
          obscure: _obscurePass,
          suffix: _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          onSuffix: () => setState(() => _obscurePass = !_obscurePass)),
      const SizedBox(height: 12),
      _lbl('CONFIRM PASSWORD'),
      _inp(_confirmCtrl, 'Re-enter password', Icons.lock_outline_rounded,
          obscure: _obscureConfirm,
          suffix: _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          onSuffix: () => setState(() => _obscureConfirm = !_obscureConfirm)),
      const SizedBox(height: 16),
      _btn('Reset Password', auth, () => _resetPassword(auth)),
    ]);

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: GoogleFonts.poppins(fontSize: 9,
        fontWeight: FontWeight.w700,
        color: Colors.white.withOpacity(0.35), letterSpacing: 1.5)));

  Widget _inp(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure=false, TextInputType? keyboard, int? maxLen,
       bool center=false, IconData? suffix, VoidCallback? onSuffix}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(children: [
        Icon(icon, size: 16, color: _teal.withOpacity(0.55)),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: ctrl, obscureText: obscure,
          keyboardType: keyboard, maxLength: maxLen,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white, letterSpacing: 1.1),
          decoration: InputDecoration(
            hintText: hint, border: InputBorder.none, isDense: true, counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            hintStyle: GoogleFonts.poppins(fontSize: 12,
                color: Colors.white.withOpacity(0.20))))),
        if (suffix != null)
          GestureDetector(onTap: onSuffix,
            child: Icon(suffix, size: 16, color: Colors.white30)),
      ]));
  }

  Widget _btn(String label, AuthProvider auth, VoidCallback onTap) =>
    SizedBox(width: double.infinity, height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: auth.isLoading ? null
              : const LinearGradient(colors: [Color(0xFF3BBFB8), Color(0xFF4ECDC4)]),
          color: auth.isLoading ? _teal.withOpacity(0.3) : null,
          boxShadow: auth.isLoading ? null : [BoxShadow(
            color: _teal.withOpacity(0.25), blurRadius: 12,
            offset: const Offset(0, 4))]),
        child: ElevatedButton(
          onPressed: auth.isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: auth.isLoading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(label, style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)))));
}

class _GridPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size sz) {
    final p = Paint()..color = Colors.white.withOpacity(0.025);
    for (double x = 0; x < sz.width; x += 28)
      for (double y = 0; y < sz.height; y += 28)
        canvas.drawCircle(Offset(x, y), 1.2, p);
  }
  @override bool shouldRepaint(_GridPainter _) => false;
}
