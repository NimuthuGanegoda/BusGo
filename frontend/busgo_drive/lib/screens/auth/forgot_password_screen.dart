import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';

// UFR_36: Common weak passwords
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
  if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(pw)) score++;
  if (score <= 2) return 1;
  if (score <= 3) return 2;
  return 3;
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl   = TextEditingController();
  final _pinCtrl     = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  int     _step    = 0;
  bool    _loading = false;
  String? _error;
  String  _email   = '';
  String  _token   = '';
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  int  _passStrength   = 0; // UFR_36

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(() {
      setState(() => _passStrength = _passwordStrength(_passCtrl.text));
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _pinCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendPin() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { setState(() => _error = 'Please enter your email'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        setState(() { _email = email; _step = 1; _loading = false; });
      } else {
        final b = jsonDecode(res.body);
        setState(() { _error = b['message'] ?? 'Failed to send PIN'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection failed. Try again.'; _loading = false; });
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) { setState(() => _error = 'Please enter the PIN'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _email, 'pin': pin}),
      ).timeout(const Duration(seconds: 15));
      final b = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() { _token = b['data']?['reset_token'] ?? ''; _step = 2; _loading = false; });
      } else {
        setState(() { _error = b['message'] ?? 'Invalid PIN'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection failed. Try again.'; _loading = false; });
    }
  }

  Future<void> _resetPassword() async {
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pass.length < 8) { setState(() => _error = 'Minimum 8 characters'); return; }
    if (_kCommonPasswords.contains(pass.toLowerCase())) {
      setState(() => _error = 'This password is too common. Choose a stronger one.'); return;
    }
    if (_passStrength == 1) {
      setState(() => _error = 'Password is too weak. Add uppercase, numbers or symbols.'); return;
    }
    if (pass != confirm) { setState(() => _error = 'Passwords do not match'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reset_token': _token, 'new_password': pass, 'confirm_password': confirm}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Password reset successfully!'), backgroundColor: Colors.green));
          context.go('/login');
        }
      } else {
        final b = jsonDecode(res.body);
        setState(() { _error = b['message'] ?? 'Reset failed'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection failed. Try again.'; _loading = false; });
    }
  }

  // UFR_36: strength bar widget
  Widget _buildStrengthBar() {
    final labels = ['', 'Weak', 'Medium', 'Strong'];
    final colors = [Colors.transparent, Colors.red, Colors.orange, Colors.green];
    final label  = labels[_passStrength];
    final color  = colors[_passStrength];
    String msg = '';
    if (_passStrength == 1) {
      if (_kCommonPasswords.contains(_passCtrl.text.toLowerCase())) {
        msg = '⚠️ This is a commonly used password';
      } else {
        msg = 'Add uppercase letters, numbers, or symbols';
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Row(children: List.generate(3, (i) => Expanded(
          child: Container(
            height: 4, margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
            decoration: BoxDecoration(
              color: i < _passStrength ? color : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2)),
          ),
        )))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
      if (msg.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(msg, style: TextStyle(fontSize: 11, color: Colors.red.shade300)),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2342),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2342), elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/login')),
        title: Text('Reset Password', style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: List.generate(3, (i) => Expanded(child: Container(
            height: 4, margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            decoration: BoxDecoration(
              color: i <= _step ? const Color(0xFF64B5F6) : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2)),
          )))),
          const SizedBox(height: 32),
          Text(_step == 0 ? 'Enter your email' : _step == 1 ? 'Enter PIN' : 'New Password',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text(_step == 0 ? 'We\'ll send a reset PIN to your email'
            : _step == 1 ? 'Check your email for the 6-digit PIN'
            : 'Choose a strong new password for your account',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 32),
          if (_error != null) Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent))),
            ])),
          if (_step == 0) ...[
            _field(ctrl: _emailCtrl, hint: 'your@email.com', icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 24),
            _btn('Send PIN', _sendPin),
          ],
          if (_step == 1) ...[
            _field(ctrl: _pinCtrl, hint: '6-digit PIN', icon: Icons.lock_clock_outlined,
                keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            _btn('Verify PIN', _verifyPin),
          ],
          if (_step == 2) ...[
            _field(ctrl: _passCtrl, hint: 'New password', icon: Icons.lock_outline,
                obscure: _obscurePass,
                suffixIcon: _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                onSuffix: () => setState(() => _obscurePass = !_obscurePass)),
            if (_passCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildStrengthBar(),
            ],
            const SizedBox(height: 14),
            _field(ctrl: _confirmCtrl, hint: 'Confirm password', icon: Icons.lock_outline,
                obscure: _obscureConfirm,
                suffixIcon: _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                onSuffix: () => setState(() => _obscureConfirm = !_obscureConfirm)),
            const SizedBox(height: 24),
            _btn('Reset Password', _resetPassword),
          ],
        ]),
      )),
    );
  }

  Widget _field({required TextEditingController ctrl, required String hint,
      required IconData icon, bool obscure = false, IconData? suffixIcon,
      VoidCallback? onSuffix, TextInputType? keyboardType}) =>
    TextField(controller: ctrl, obscureText: obscure, keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.28)),
        filled: true, fillColor: Colors.white.withOpacity(0.06),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64B5F6).withOpacity(0.65)),
        suffixIcon: suffixIcon != null
            ? GestureDetector(onTap: onSuffix, child: Icon(suffixIcon, size: 18, color: Colors.white38))
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 1.5)),
      ));

  Widget _btn(String label, VoidCallback onTap) =>
    SizedBox(width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: _loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700))));
}
