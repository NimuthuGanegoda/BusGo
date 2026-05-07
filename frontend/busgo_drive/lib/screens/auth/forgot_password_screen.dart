import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';

const List<String> _kCommonPasswords = [
  'password', 'password1', 'password123', '123456', '1234567', '12345678',
  '123456789', '1234567890', 'qwerty', 'qwerty123', 'abc123', 'letmein',
  'welcome', 'admin', 'admin123', 'monkey', 'dragon', 'master', 'hello',
  'sunshine', 'princess', 'football', 'iloveyou', 'shadow', 'superman',
  'michael', 'jessica', 'baseball', 'batman', 'trustno1', 'passw0rd',
  'busgo', 'driver', 'driver123', '000000', '111111', '666666', '888888',
];

int _passwordStrength(String pw) {
  if (pw.isEmpty) return 0;
  if (_kCommonPasswords.contains(pw.toLowerCase())) return 1;
  int score = 0;
  if (pw.length >= 8)  score++;
  if (pw.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
  if (RegExp(r'[0-9]').hasMatch(pw)) score++;
  if (RegExp(r'[!@#\$%^&*(),.?\":{}|<>_\-]').hasMatch(pw)) score++;
  if (score <= 2) return 1;
  if (score <= 3) return 2;
  return 3;
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int     _step    = 1;
  bool    _loading = false;
  String? _error;

  String _email = '';
  String _pin   = '';
  String _token = '';

  final _emailCtrl   = TextEditingController();
  final _pinCtrl     = TextEditingController();
  final _answer1Ctrl = TextEditingController();
  final _answer2Ctrl = TextEditingController();
  final _answer3Ctrl = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  int  _passStrength   = 0;

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(() {
      setState(() => _passStrength = _passwordStrength(_passCtrl.text));
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pinCtrl.dispose();
    _answer1Ctrl.dispose();
    _answer2Ctrl.dispose();
    _answer3Ctrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submitEmail() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() { _email = email; _error = null; _step = 2; });
  }

  void _submitPin() {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Please enter your recovery PIN');
      return;
    }
    setState(() { _pin = pin; _error = null; _step = 3; });
  }

  Future<void> _submitAnswers() async {
    final a1 = _answer1Ctrl.text.trim();
    final a2 = _answer2Ctrl.text.trim();
    final a3 = _answer3Ctrl.text.trim();
    if (a1.isEmpty || a2.isEmpty || a3.isEmpty) {
      setState(() => _error = 'Please answer all three questions');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password/verify-identity'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':        _email,
          'recovery_pin': _pin,
          'answer_1':     a1,
          'answer_2':     a2,
          'answer_3':     a3,
        }),
      ).timeout(const Duration(seconds: 15));
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        final data = b['data'] as Map<String, dynamic>?;
        _token = data?['reset_token'] as String? ?? '';
        setState(() { _step = 4; _loading = false; });
      } else {
        setState(() {
          _error   = b['message'] as String? ??
              'Verification failed. Please check your PIN and answers.';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error   = 'Connection failed. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pass.length < 8) {
      setState(() => _error = 'Minimum 8 characters');
      return;
    }
    if (_kCommonPasswords.contains(pass.toLowerCase())) {
      setState(() =>
          _error = 'This password is too common. Choose a stronger one.');
      return;
    }
    if (_passStrength == 1) {
      setState(() =>
          _error = 'Password is too weak. Add uppercase, numbers or symbols.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reset_token':      _token,
          'new_password':     pass,
          'confirm_password': confirm,
        }),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Password reset successfully!'),
            backgroundColor: Colors.green));
          context.go('/login');
        }
      } else {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _error   = b['message'] as String? ?? 'Reset failed';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error   = 'Connection failed. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2342),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2342), elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_step > 1) {
              setState(() { _step--; _error = null; });
            } else {
              context.go('/login');
            }
          }),
        title: Text('Reset Password', style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: Colors.white)),
      ),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Row(children: List.generate(4, (i) => Expanded(child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
            decoration: BoxDecoration(
              color: i < _step
                  ? const Color(0xFF64B5F6)
                  : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2)),
          )))),

          const SizedBox(height: 32),

          Text(_stepTitle, style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: Colors.white)),
          const SizedBox(height: 8),
          Text(_stepSubtitle, style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 32),

          if (_error != null) Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.error_outline, size: 16,
                  color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.redAccent))),
            ])),

          if (_step == 1) ...[
            _field(ctrl: _emailCtrl, hint: 'your@email.com',
                icon: Icons.email_outlined,
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 24),
            _btn('Continue', onTap: _submitEmail),
          ],

          if (_step == 2) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF64B5F6).withOpacity(0.3))),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 16,
                    color: const Color(0xFF64B5F6).withOpacity(0.8)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Use the 6-digit PIN that was shown\n'
                  'when you created your account.',
                  style: GoogleFonts.inter(fontSize: 11,
                      color: const Color(0xFF64B5F6).withOpacity(0.9)))),
              ])),
            _field(ctrl: _pinCtrl, hint: '6-digit recovery PIN',
                icon: Icons.lock_outline,
                keyboard: TextInputType.number),
            const SizedBox(height: 24),
            _btn('Continue', onTap: _submitPin),
          ],

          if (_step == 3) ...[
            _lbl('Q1: What is your mother\'s maiden name?'),
            const SizedBox(height: 6),
            _field(ctrl: _answer1Ctrl, hint: 'Your answer',
                icon: Icons.help_outline_rounded),
            const SizedBox(height: 14),
            _lbl('Q2: What was the name of your first pet?'),
            const SizedBox(height: 6),
            _field(ctrl: _answer2Ctrl, hint: 'Your answer',
                icon: Icons.help_outline_rounded),
            const SizedBox(height: 14),
            _lbl('Q3: What city were you born in?'),
            const SizedBox(height: 6),
            _field(ctrl: _answer3Ctrl, hint: 'Your answer',
                icon: Icons.help_outline_rounded),
            const SizedBox(height: 24),
            _btn('Verify Identity', onTap: _submitAnswers),
          ],

          if (_step == 4) ...[
            _field(ctrl: _passCtrl, hint: 'New password',
                icon: Icons.lock_outline, obscure: _obscurePass,
                suffixIcon: _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onSuffix: () =>
                    setState(() => _obscurePass = !_obscurePass)),
            if (_passCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildStrengthBar(),
            ],
            const SizedBox(height: 14),
            _field(ctrl: _confirmCtrl, hint: 'Confirm password',
                icon: Icons.lock_outline, obscure: _obscureConfirm,
                suffixIcon: _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onSuffix: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm)),
            const SizedBox(height: 24),
            _btn('Reset Password', onTap: _resetPassword),
          ],

        ]),
      )),
    );
  }

  String get _stepTitle => switch (_step) {
    1 => 'Reset Password',
    2 => 'Recovery PIN',
    3 => 'Security Questions',
    _ => 'New Password',
  };

  String get _stepSubtitle => switch (_step) {
    1 => 'Enter the email you registered with',
    2 => 'Enter the 6-digit PIN shown\nwhen you created your account',
    3 => 'Answer your security questions\nto verify your identity',
    _ => 'Choose a strong new password\nfor your account',
  };

  Widget _buildStrengthBar() {
    final labels = ['', 'Weak', 'Medium', 'Strong'];
    final colors = [
      Colors.transparent, Colors.red, Colors.orange, Colors.green];
    final label = labels[_passStrength];
    final color = colors[_passStrength];
    String msg = '';
    if (_passStrength == 1) {
      msg = _kCommonPasswords.contains(_passCtrl.text.toLowerCase())
          ? '⚠ This is a commonly used password'
          : 'Add uppercase letters, numbers, or symbols';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Row(children: List.generate(3, (i) => Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
            decoration: BoxDecoration(
              color: i < _passStrength
                  ? color : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2)),
          ),
        )))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
      if (msg.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(msg, style: TextStyle(
            fontSize: 11, color: Colors.red.shade300)),
      ],
    ]);
  }

  Widget _lbl(String t) => Text(t, style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w600,
      color: Colors.white.withOpacity(0.5),
      letterSpacing: 0.5));

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    IconData? suffixIcon,
    VoidCallback? onSuffix,
    TextInputType? keyboard,
  }) => TextField(
    controller: ctrl, obscureText: obscure, keyboardType: keyboard,
    style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13,
          color: Colors.white.withOpacity(0.28)),
      filled: true, fillColor: Colors.white.withOpacity(0.06),
      prefixIcon: Icon(icon, size: 18,
          color: const Color(0xFF64B5F6).withOpacity(0.65)),
      suffixIcon: suffixIcon != null
          ? GestureDetector(onTap: onSuffix,
              child: Icon(suffixIcon, size: 18, color: Colors.white38))
          : null,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withOpacity(0.09))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF64B5F6), width: 1.5)),
    ));

  Widget _btn(String label, {required VoidCallback onTap}) =>
    SizedBox(width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        child: _loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700))));
}