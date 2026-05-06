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

  static const _bg    = Color(0xFF040D18);
  static const _teal  = Color(0xFF4ECDC4);
  static const _panel = Color(0xFF0A1628);

  // Local step management — 1=email, 2=pin, 3=answers, 4=new password
  int     _step  = 1;
  String  _email = '';

  final _emailCtrl    = TextEditingController();
  final _pinCtrl      = TextEditingController();
  final _answer1Ctrl  = TextEditingController();
  final _answer2Ctrl  = TextEditingController();
  final _answer3Ctrl  = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  late AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().resetForgotPassword();
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _emailCtrl.dispose();
    _pinCtrl.dispose();
    _answer1Ctrl.dispose();
    _answer2Ctrl.dispose();
    _answer3Ctrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: store email locally and move to step 2 ───────────────────────
  void _submitEmail() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      BusgoAlert.show(context,
          type: BusgoAlertType.error,
          title: 'Email Required',
          message: 'Please enter your email address.');
      return;
    }
    final emailRx = RegExp(
        r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!emailRx.hasMatch(email)) {
      BusgoAlert.show(context,
          type: BusgoAlertType.error,
          title: 'Invalid Email',
          message: 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _email = email;
      _step  = 2;
    });
  }

  // ── Step 2: store PIN locally and move to step 3 ─────────────────────────
  void _submitPin() {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      BusgoAlert.show(context,
          type: BusgoAlertType.error,
          title: 'PIN Required',
          message: 'Please enter your 6-digit recovery PIN.');
      return;
    }
    setState(() => _step = 3);
  }

  // ── Step 3: verify identity with backend ─────────────────────────────────
  Future<void> _submitAnswers(AuthProvider auth) async {
    final a1 = _answer1Ctrl.text.trim();
    final a2 = _answer2Ctrl.text.trim();
    final a3 = _answer3Ctrl.text.trim();

    if (a1.isEmpty || a2.isEmpty || a3.isEmpty) {
      BusgoAlert.show(context,
          type: BusgoAlertType.error,
          title: 'All Answers Required',
          message: 'Please answer all three security questions.');
      return;
    }

    final ok = await auth.verifyIdentity(
      email:       _email,
      recoveryPin: _pinCtrl.text.trim(),
      answer1:     a1,
      answer2:     a2,
      answer3:     a3,
    );

    if (!mounted) return;
    if (ok) {
      setState(() => _step = 4);
    } else {
      BusgoAlert.show(context,
          type: BusgoAlertType.error,
          title: 'Verification Failed',
          message: auth.errorMessage ??
              'Incorrect PIN or answers. Please try again.');
      auth.clearError();
    }
  }

  // ── Step 4: reset password ────────────────────────────────────────────────
  Future<void> _resetPassword(AuthProvider auth) async {
    final ok = await auth.resetPassword(
        _passCtrl.text, _confirmCtrl.text);
    if (!mounted) return;
    if (ok) {
      BusgoAlert.show(context,
          type: BusgoAlertType.success,
          title: 'Password Reset!',
          message: 'You can now sign in with your new password.');
      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      context.go('/login');
    } else if (auth.errorMessage != null) {
      BusgoAlert.show(context,
          type: BusgoAlertType.error,
          title: 'Reset Failed',
          message: auth.errorMessage!);
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
        opacity: CurvedAnimation(
            parent: _enterCtrl, curve: Curves.easeOut),
        child: Consumer<AuthProvider>(builder: (ctx, auth, _) {
          return Stack(children: [
            Container(decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.6), radius: 1.1,
                  colors: [Color(0xFF0A1E30), Color(0xFF040D18)]))),
            CustomPaint(size: size, painter: _GridPainter()),

            SafeArea(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(children: [

                // Header
                Row(children: [
                  GestureDetector(
                    onTap: () {
                      if (_step > 1) {
                        setState(() => _step--);
                      } else {
                        context.pop();
                      }
                    },
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _panel,
                        border: Border.all(
                            color: _teal.withOpacity(0.2))),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: Colors.white70))),
                  const SizedBox(width: 14),
                  Text('BUSGO', style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 4)),
                ]),

                const SizedBox(height: 32),

                // Icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(_step),
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _panel,
                      border: Border.all(
                          color: _teal.withOpacity(0.25), width: 1.5),
                      boxShadow: [BoxShadow(
                          color: _teal.withOpacity(0.10),
                          blurRadius: 20, spreadRadius: 3)]),
                    child: Icon(_stepIcon, size: 28, color: _teal))),

                const SizedBox(height: 16),

                Text(_stepTitle, style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: Colors.white)),

                const SizedBox(height: 6),

                Text(_stepSubtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF6B7A8D))),

                const SizedBox(height: 26),

                // Step dots
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(1), _line(), _dot(2),
                    _line(), _dot(3), _line(), _dot(4),
                  ]),

                const SizedBox(height: 26),

                // Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _panel.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _teal.withOpacity(0.12))),
                  padding: const EdgeInsets.all(20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, anim) =>
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.12, 0),
                            end: Offset.zero).animate(anim),
                          child: FadeTransition(
                              opacity: anim, child: child)),
                    child: _buildStepContent(auth))),

                const SizedBox(height: 20),

                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back_rounded,
                          size: 14,
                          color: _teal.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Text('Back to Login',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _teal.withOpacity(0.6),
                              fontWeight: FontWeight.w500)),
                    ])),
              ]))),
          ]);
        }),
      ),
    );
  }

  IconData get _stepIcon => switch (_step) {
    1 => Icons.email_outlined,
    2 => Icons.lock_outlined,
    3 => Icons.help_outline_rounded,
    _ => Icons.lock_open_rounded,
  };

  String get _stepTitle => switch (_step) {
    1 => 'Reset Password',
    2 => 'Recovery PIN',
    3 => 'Security Questions',
    _ => 'New Password',
  };

  String get _stepSubtitle => switch (_step) {
    1 => 'Enter the email you registered with',
    2 => 'Enter the 6-digit PIN shown\nafter registration',
    3 => 'Answer your security questions\nto verify your identity',
    _ => 'Choose a strong new password\nfor your account',
  };

  Widget _buildStepContent(AuthProvider auth) =>
      switch (_step) {
        1 => _step1(key: const ValueKey(1)),
        2 => _step2(key: const ValueKey(2)),
        3 => _step3(auth, key: const ValueKey(3)),
        _ => _step4(auth, key: const ValueKey(4)),
      };

  // ── Step 1: Email ─────────────────────────────────────────────────────────
  Widget _step1({Key? key}) => Column(
    key: key,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _lbl('EMAIL ADDRESS'),
      _inp(_emailCtrl, 'your@email.com',
          Icons.email_outlined,
          keyboard: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _btn('Continue', null, _submitEmail),
    ]);

  // ── Step 2: Recovery PIN ──────────────────────────────────────────────────
  Widget _step2({Key? key}) => Column(
    key: key,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _teal.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _teal.withOpacity(0.2))),
        child: Row(children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: _teal.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Use the 6-digit PIN that was shown\n'
            'when you created your account.',
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: _teal.withOpacity(0.8)))),
        ])),
      const SizedBox(height: 14),
      _lbl('6-DIGIT RECOVERY PIN'),
      _inp(_pinCtrl, '• • • • • •',
          Icons.pin_outlined,
          keyboard: TextInputType.number,
          maxLen: 6, center: true),
      const SizedBox(height: 16),
      _btn('Continue', null, _submitPin),
    ]);

  // ── Step 3: Security questions ────────────────────────────────────────────
  Widget _step3(AuthProvider auth, {Key? key}) => Column(
    key: key,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _lbl('Q1: What is your mother\'s maiden name?'),
      _inp(_answer1Ctrl, 'Your answer', Icons.help_outline_rounded),
      const SizedBox(height: 4),
      _lbl('Q2: What was the name of your first pet?'),
      _inp(_answer2Ctrl, 'Your answer', Icons.help_outline_rounded),
      const SizedBox(height: 4),
      _lbl('Q3: What city were you born in?'),
      _inp(_answer3Ctrl, 'Your answer', Icons.help_outline_rounded),
      const SizedBox(height: 16),
      _btn('Verify Identity', auth, () => _submitAnswers(auth)),
    ]);

  // ── Step 4: New password ──────────────────────────────────────────────────
  Widget _step4(AuthProvider auth, {Key? key}) => Column(
    key: key,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _lbl('NEW PASSWORD'),
      _inp(_passCtrl, 'Min. 8 characters',
          Icons.lock_outline_rounded,
          obscure: _obscurePass,
          suffix: _obscurePass
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          onSuffix: () =>
              setState(() => _obscurePass = !_obscurePass)),
      const SizedBox(height: 12),
      _lbl('CONFIRM PASSWORD'),
      _inp(_confirmCtrl, 'Re-enter password',
          Icons.lock_outline_rounded,
          obscure: _obscureConfirm,
          suffix: _obscureConfirm
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          onSuffix: () => setState(
              () => _obscureConfirm = !_obscureConfirm)),
      const SizedBox(height: 16),
      _btn('Reset Password', auth, () => _resetPassword(auth)),
    ]);

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _dot(int n) {
    final active = n == _step;
    final done   = n < _step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 34 : 28, height: active ? 34 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? _teal
            : active
                ? _teal.withOpacity(0.12)
                : Colors.white.withOpacity(0.05),
        border: Border.all(
          color: (active || done)
              ? _teal
              : Colors.white.withOpacity(0.12),
          width: active ? 2 : 1.5)),
      child: Center(child: done
          ? const Icon(Icons.check_rounded,
              size: 14, color: Colors.white)
          : Text('$n', style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: active
                  ? _teal
                  : Colors.white.withOpacity(0.3)))));
  }

  Widget _line() => Container(
    width: 28, height: 1.5,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: Colors.white.withOpacity(0.08));

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: GoogleFonts.poppins(
        fontSize: 9, fontWeight: FontWeight.w700,
        color: Colors.white.withOpacity(0.35),
        letterSpacing: 1.2)));

  Widget _inp(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false, TextInputType? keyboard,
       int? maxLen, bool center = false,
       IconData? suffix, VoidCallback? onSuffix}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(children: [
        Icon(icon, size: 16, color: _teal.withOpacity(0.55)),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboard,
          maxLength: maxLen,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
              fontSize: 14, color: Colors.white,
              letterSpacing: 1.1),
          decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            isDense: true,
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12),
            hintStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withOpacity(0.20))))),
        if (suffix != null)
          GestureDetector(
            onTap: onSuffix,
            child: Icon(suffix, size: 16, color: Colors.white30)),
      ]));
  }

  Widget _btn(String label, AuthProvider? auth,
      VoidCallback onTap) =>
      SizedBox(
        width: double.infinity, height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: (auth?.isLoading ?? false) ? null
                : const LinearGradient(
                    colors: [Color(0xFF3BBFB8), Color(0xFF4ECDC4)]),
            color: (auth?.isLoading ?? false)
                ? _teal.withOpacity(0.3) : null,
            boxShadow: (auth?.isLoading ?? false) ? null
                : [BoxShadow(
                    color: _teal.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4))]),
          child: ElevatedButton(
            onPressed: (auth?.isLoading ?? false) ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
            child: (auth?.isLoading ?? false)
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text(label, style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Colors.white)))));
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