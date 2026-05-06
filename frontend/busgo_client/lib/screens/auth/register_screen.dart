import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _dobCtrl      = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _answer1Ctrl  = TextEditingController();
  final _answer2Ctrl  = TextEditingController();
  final _answer3Ctrl  = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  final Map<String, String?> _errors = {};

  late AnimationController _enterCtrl;

  static const _bg    = Color(0xFF040D18);
  static const _teal  = Color(0xFF4ECDC4);
  static const _panel = Color(0xFF0A1628);

  static const _commonPasswords = [
    'password', 'password1', 'password123', '12345678', '123456789',
    'qwerty123', 'iloveyou', 'admin123', 'letmein', 'welcome',
    'monkey123', 'dragon', 'master', 'abc12345', 'pass1234',
    '11111111', '00000000', 'test1234', 'busgo123', 'busgo1234',
    'qwerty', 'abc123', '1234567890', 'sunshine', 'princess',
  ];

  bool _isCommonPassword(String pass) =>
      _commonPasswords.contains(pass.toLowerCase());

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))..forward();
    for (final c in [
      _fullNameCtrl, _emailCtrl, _usernameCtrl, _phoneCtrl,
      _dobCtrl, _passCtrl, _confirmCtrl,
      _answer1Ctrl, _answer2Ctrl, _answer3Ctrl,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    for (final c in [
      _fullNameCtrl, _emailCtrl, _usernameCtrl, _phoneCtrl,
      _dobCtrl, _passCtrl, _confirmCtrl,
      _answer1Ctrl, _answer2Ctrl, _answer3Ctrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _progress {
    int n = 0;
    if (_fullNameCtrl.text.isNotEmpty) n++;
    if (_emailCtrl.text.isNotEmpty) n++;
    if (_usernameCtrl.text.isNotEmpty) n++;
    if (_phoneCtrl.text.isNotEmpty) n++;
    if (_passCtrl.text.isNotEmpty) n++;
    if (_confirmCtrl.text.isNotEmpty) n++;
    if (_answer1Ctrl.text.isNotEmpty) n++;
    if (_answer2Ctrl.text.isNotEmpty) n++;
    if (_answer3Ctrl.text.isNotEmpty) n++;
    return n / 9;
  }

  int _strengthScore(String pass) {
    int score = 0;
    if (pass.length >= 8)  score++;
    if (pass.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(pass)) score++;
    if (RegExp(r'[0-9]').hasMatch(pass)) score++;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(pass)) score++;
    return score;
  }

  Widget _buildPasswordStrength(String pass) {
    if (pass.isEmpty) return const SizedBox.shrink();
    final score = _strengthScore(pass);
    final label = score <= 1 ? 'Weak' : score <= 3 ? 'Fair' : 'Strong';
    final color = score <= 1
        ? const Color(0xFFEF4444)
        : score <= 3 ? const Color(0xFFF59E0B) : const Color(0xFF22C55E);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: score / 5,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 3))),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.poppins(
            fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  bool _validate() {
    _errors.clear();
    if (_fullNameCtrl.text.trim().isEmpty)
      _errors['name'] = 'Full name is required';
    final emailRx = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (_emailCtrl.text.trim().isEmpty)
      _errors['email'] = 'Email is required';
    else if (!emailRx.hasMatch(_emailCtrl.text.trim()))
      _errors['email'] = 'Enter a valid email';
    if (_usernameCtrl.text.trim().isEmpty)
      _errors['username'] = 'Username is required';
    else if (_usernameCtrl.text.trim().length < 3)
      _errors['username'] = 'Min 3 characters';
    if (_phoneCtrl.text.trim().isEmpty)
      _errors['phone'] = 'Phone is required';
    if (_passCtrl.text.isEmpty) {
      _errors['pass'] = 'Password is required';
    } else if (_passCtrl.text.length < 8) {
      _errors['pass'] = 'Min 8 characters';
    } else if (_isCommonPassword(_passCtrl.text)) {
      _errors['pass'] = 'Password is too common. Choose something unique.';
    }
    if (_confirmCtrl.text.isEmpty)
      _errors['confirm'] = 'Please confirm your password';
    else if (_confirmCtrl.text != _passCtrl.text)
      _errors['confirm'] = 'Passwords do not match';
    if (_answer1Ctrl.text.trim().isEmpty)
      _errors['a1'] = 'Answer is required';
    if (_answer2Ctrl.text.trim().isEmpty)
      _errors['a2'] = 'Answer is required';
    if (_answer3Ctrl.text.trim().isEmpty)
      _errors['a3'] = 'Answer is required';
    setState(() {});
    return _errors.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
        child: Stack(children: [
          Container(decoration: const BoxDecoration(gradient: RadialGradient(
            center: Alignment(0.3, -0.5), radius: 1.2,
            colors: [Color(0xFF0A1E30), Color(0xFF040D18)]))),
          CustomPaint(size: size, painter: _GridPainter()),

          // Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: _panel,
                        border: Border.all(color: _teal.withOpacity(0.2))),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: Colors.white70))),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BUSGO', style: GoogleFonts.poppins(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 5)),
                    Text('Create your account', style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.white.withOpacity(0.35))),
                  ]),
                  const Spacer(),
                  SizedBox(width: 38, height: 38,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(_teal),
                        strokeWidth: 3),
                      Text('${(_progress * 100).round()}%',
                        style: GoogleFonts.poppins(
                          fontSize: 8, color: _teal,
                          fontWeight: FontWeight.w700)),
                    ])),
                ]),
              ),
            ),
          ),

          // Scrollable form
          Positioned(
            top: 0, left: 0, right: 0, bottom: 0,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Consumer<AuthProvider>(builder: (ctx, auth, _) =>
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(_teal),
                        minHeight: 3)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('Profile completion',
                        style: GoogleFonts.poppins(fontSize: 10,
                            color: Colors.white.withOpacity(0.25))),
                      const Spacer(),
                      Text('${(_progress * 100).round()}% complete',
                        style: GoogleFonts.poppins(fontSize: 10,
                            color: _teal.withOpacity(0.7))),
                    ]),

                    const SizedBox(height: 20),

                    _section('Personal'),
                    _field('Full Name', 'Your full name',
                        Icons.person_rounded, _fullNameCtrl,
                        error: _errors['name']),
                    _field('Email', 'you@example.com',
                        Icons.email_outlined, _emailCtrl,
                        error: _errors['email'],
                        keyboard: TextInputType.emailAddress),
                    _field('Username', '@username',
                        Icons.alternate_email_rounded, _usernameCtrl,
                        error: _errors['username']),
                    _field('Phone', '07X XXX XXXX',
                        Icons.phone_rounded, _phoneCtrl,
                        error: _errors['phone'],
                        keyboard: TextInputType.phone),
                    _field('Date of Birth (optional)', 'YYYY-MM-DD',
                        Icons.calendar_month_rounded, _dobCtrl,
                        keyboard: TextInputType.datetime),

                    const SizedBox(height: 8),
                    _section('Security'),
                    _field('Password', 'Min. 8 characters',
                        Icons.lock_outline_rounded, _passCtrl,
                        error: _errors['pass'], obscure: _obscurePass,
                        onToggle: () =>
                            setState(() => _obscurePass = !_obscurePass)),
                    _buildPasswordStrength(_passCtrl.text),
                    _field('Confirm Password', 'Re-enter password',
                        Icons.lock_outline_rounded, _confirmCtrl,
                        error: _errors['confirm'],
                        obscure: _obscureConfirm,
                        onToggle: () => setState(
                            () => _obscureConfirm = !_obscureConfirm)),

                    const SizedBox(height: 8),
                    _section('Recovery Questions'),

                    // Info banner
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _teal.withOpacity(0.2))),
                      child: Row(children: [
                        Icon(Icons.shield_outlined,
                            size: 16, color: _teal.withOpacity(0.8)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          'These answers + a recovery PIN will be shown '
                          'after registration. Save them — you\'ll need '
                          'them to reset your password.',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: _teal.withOpacity(0.8),
                              height: 1.5))),
                      ])),

                    _field(
                      'Q1: What is your mother\'s maiden name?',
                      'Your answer',
                      Icons.help_outline_rounded,
                      _answer1Ctrl,
                      error: _errors['a1'],
                    ),
                    _field(
                      'Q2: What was the name of your first pet?',
                      'Your answer',
                      Icons.help_outline_rounded,
                      _answer2Ctrl,
                      error: _errors['a2'],
                    ),
                    _field(
                      'Q3: What city were you born in?',
                      'Your answer',
                      Icons.help_outline_rounded,
                      _answer3Ctrl,
                      error: _errors['a3'],
                    ),

                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFF6B6B).withOpacity(0.3))),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 14, color: Color(0xFFFF9999)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(auth.errorMessage!,
                            style: GoogleFonts.poppins(fontSize: 11,
                                color: const Color(0xFFFF9999)))),
                        ])),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity, height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: auth.isLoading ? null
                              : const LinearGradient(
                                  colors: [Color(0xFF3BBFB8), Color(0xFF4ECDC4)]),
                          color: auth.isLoading
                              ? _teal.withOpacity(0.3) : null,
                          boxShadow: auth.isLoading ? null : [BoxShadow(
                            color: _teal.withOpacity(0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 5))]),
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : () async {
                            auth.clearError();
                            if (!_validate()) return;
                            if (_dobCtrl.text.trim().isNotEmpty &&
                                !RegExp(r'^\d{4}-\d{2}-\d{2}$')
                                    .hasMatch(_dobCtrl.text.trim())) {
                              setState(() => _errors['dob'] = 'Use YYYY-MM-DD');
                              return;
                            }
                            final ok = await auth.register(
                              fullName:    _fullNameCtrl.text.trim(),
                              email:       _emailCtrl.text.trim(),
                              username:    _usernameCtrl.text.trim(),
                              phone:       _phoneCtrl.text.trim(),
                              password:    _passCtrl.text,
                              dateOfBirth: _dobCtrl.text.trim().isNotEmpty
                                  ? _dobCtrl.text.trim() : null,
                              answer1:     _answer1Ctrl.text.trim(),
                              answer2:     _answer2Ctrl.text.trim(),
                              answer3:     _answer3Ctrl.text.trim(),
                            );
                            if (ok && mounted) {
                              final pin = auth.recoveryPin;
                              if (pin != null) {
                                context.push('/recovery-pin', extra: pin);
                              } else {
                                context.go('/login');
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                          child: auth.isLoading
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : Text('Create Account',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white))))),

                    const SizedBox(height: 14),

                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Already have an account? ',
                        style: GoogleFonts.poppins(fontSize: 12,
                            color: Colors.white.withOpacity(0.35))),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text('Sign In', style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _teal))),
                    ]),

                    const SizedBox(height: 20),
                  ])),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Text(label, style: GoogleFonts.poppins(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: _teal.withOpacity(0.7), letterSpacing: 1.2)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: _teal.withOpacity(0.12), thickness: 1)),
    ]));

  Widget _field(String label, String hint, IconData icon,
      TextEditingController ctrl,
      {String? error, bool obscure = false, VoidCallback? onToggle,
       TextInputType? keyboard}) {
    final hasError = error != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.poppins(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.45))),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
          color: hasError
              ? const Color(0xFFFF6B6B).withOpacity(0.06)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasError
                ? const Color(0xFFFF6B6B).withOpacity(0.4)
                : ctrl.text.isNotEmpty
                    ? _teal.withOpacity(0.35)
                    : Colors.white.withOpacity(0.08),
            width: 1.2)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Row(children: [
          Icon(icon, size: 16,
              color: ctrl.text.isNotEmpty
                  ? _teal.withOpacity(0.7) : Colors.white30),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: keyboard,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
              hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.20))))),
          if (onToggle != null)
            GestureDetector(
              onTap: onToggle,
              child: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                  color: Colors.white30)),
        ])),
      if (hasError)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text(error,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: const Color(0xFFFF9999)))),
      const SizedBox(height: 12),
    ]);
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size sz) {
    final p = Paint()..color = Colors.white.withOpacity(0.025);
    for (double x = 0; x < sz.width; x += 28) {
      for (double y = 0; y < sz.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }
  @override bool shouldRepaint(_GridPainter _) => false;
}