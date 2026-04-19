import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Steps: 1 = enter email, 2 = enter PIN, 3 = new password, 4 = success
  int _step = 1;

  final _emailController    = TextEditingController();
  final _pinController      = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool    _isLoading       = false;
  String? _error;
  String? _resetToken;
  bool    _obscurePassword = true;
  bool    _obscureConfirm  = true;
  String  _email           = '';

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Step 1: Request PIN ────────────────────────────────────────────────────
  Future<void> _requestPin() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final res = await http.post(
        Uri.parse('$kBaseUrlDev/auth/forgot-password/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim().toLowerCase()}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        _email = _emailController.text.trim().toLowerCase();
        setState(() { _step = 2; _isLoading = false; });
      } else {
        final body = jsonDecode(res.body);
        setState(() {
          _error = body['message'] ?? 'Failed to send PIN';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection failed. Is the backend running?';
        _isLoading = false;
      });
    }
  }

  // ── Step 2: Verify PIN ─────────────────────────────────────────────────────
  Future<void> _verifyPin() async {
    if (_pinController.text.trim().length != 6) {
      setState(() => _error = 'Please enter the 6-digit PIN');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final res = await http.post(
        Uri.parse('$kBaseUrlDev/auth/forgot-password/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _email,
          'pin':   _pinController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        _resetToken = body['data']['reset_token'] as String;
        setState(() { _step = 3; _isLoading = false; });
      } else {
        setState(() {
          _error = body['message'] ?? 'Invalid PIN';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection failed.';
        _isLoading = false;
      });
    }
  }

  // ── Step 3: Reset Password ─────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    if (_passwordController.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final res = await http.post(
        Uri.parse('$kBaseUrlDev/auth/forgot-password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reset_token':      _resetToken,
          'new_password':     _passwordController.text,
          'confirm_password': _confirmController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        setState(() { _step = 4; _isLoading = false; });
      } else {
        final body = jsonDecode(res.body);
        setState(() {
          _error = body['message'] ?? 'Failed to reset password';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection failed.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity, height: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF0B1A2E), Color(0xFF132F54), Color(0xFF1E5AA8)],
      )),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 40),
          _buildHeader(),
          const SizedBox(height: 32),
          _buildStepIndicator(),
          const SizedBox(height: 24),
          _buildCard(),
          const SizedBox(height: 20),
          if (_step < 4) GestureDetector(
            onTap: () => context.pop(),
            child: Text('← Back to Login',
                style: GoogleFonts.inter(fontSize: 13,
                    color: const Color(0xFF90CAF9),
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 40),
        ]),
      )),
    ),
  );

  Widget _buildHeader() => Column(children: [
    Container(width: 56, height: 56,
      decoration: BoxDecoration(color: const Color(0xFF1A6FA8),
          borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.lock_reset_rounded, size: 28, color: Colors.white)),
    const SizedBox(height: 16),
    Text('BUSGO', style: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w900,
        color: Colors.white, letterSpacing: 6)),
    const SizedBox(height: 8),
    Text('Reset Your Password', style: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
    const SizedBox(height: 4),
    Text(
      _step == 1 ? 'Enter your email to receive a PIN'
      : _step == 2 ? 'Check your email for the PIN'
      : _step == 3 ? 'Create your new password'
      : 'Password reset successfully!',
      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF90CAF9))),
  ]);

  Widget _buildStepIndicator() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (i) {
      final stepNum  = i + 1;
      final isActive = _step == stepNum;
      final isDone   = _step > stepNum;
      return Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 32 : 24, height: 24,
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF16a34a)
                : isActive ? const Color(0xFF1A6FA8)
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text('$stepNum', style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.white))),
        ),
        if (i < 2) Container(width: 32, height: 2,
            color: _step > stepNum
                ? const Color(0xFF16a34a)
                : Colors.white.withValues(alpha: 0.2)),
      ]);
    }),
  );

  Widget _buildCard() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: const Border(top: BorderSide(color: Color(0xFF1A6FA8), width: 3))),
    child: _step == 4 ? _buildSuccessContent() : Column(children: [
      if (_error != null) Container(
        width: double.infinity, padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCA5A5))),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626)))),
        ]),
      ),
      if (_step == 1) _buildStep1(),
      if (_step == 2) _buildStep2(),
      if (_step == 3) _buildStep3(),
    ]),
  );

  // ── Step 1 UI ──────────────────────────────────────────────────────────────
  Widget _buildStep1() => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('EMAIL ADDRESS', style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: const Color(0xFF888888), letterSpacing: 0.6)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF333333)),
        decoration: _inputDecoration('your@email.com', Icons.email_outlined),
      ),
      const SizedBox(height: 20),
      _buildButton('Send Reset PIN', _requestPin),
    ]);

  // ── Step 2 UI ──────────────────────────────────────────────────────────────
  Widget _buildStep2() => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE))),
        child: Row(children: [
          const Icon(Icons.email_rounded, size: 16, color: Color(0xFF1A6FA8)),
          const SizedBox(width: 8),
          Expanded(child: Text('PIN sent to $_email',
              style: GoogleFonts.inter(fontSize: 12,
                  color: const Color(0xFF1A6FA8), fontWeight: FontWeight.w600))),
        ]),
      ),
      Text('6-DIGIT PIN', style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: const Color(0xFF888888), letterSpacing: 0.6)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _pinController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800,
            color: const Color(0xFF0A2342), letterSpacing: 8),
        decoration: _inputDecoration('000000', Icons.pin_outlined)
            .copyWith(counterText: ''),
      ),
      const SizedBox(height: 20),
      _buildButton('Verify PIN', _verifyPin),
      const SizedBox(height: 12),
      Center(child: GestureDetector(
        onTap: _requestPin,
        child: Text('Resend PIN',
            style: GoogleFonts.inter(fontSize: 13,
                color: const Color(0xFF1A6FA8), fontWeight: FontWeight.w600)),
      )),
    ]);

  // ── Step 3 UI ──────────────────────────────────────────────────────────────
  Widget _buildStep3() => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('NEW PASSWORD', style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: const Color(0xFF888888), letterSpacing: 0.6)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF333333)),
        decoration: _inputDecoration('Min. 8 characters', Icons.lock_outline)
            .copyWith(suffixIcon: IconButton(
          icon: Icon(_obscurePassword
              ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: const Color(0xFFAAAAAA)),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )),
      ),
      const SizedBox(height: 14),
      Text('CONFIRM PASSWORD', style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: const Color(0xFF888888), letterSpacing: 0.6)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _confirmController,
        obscureText: _obscureConfirm,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF333333)),
        decoration: _inputDecoration('Re-enter password', Icons.lock_outline)
            .copyWith(suffixIcon: IconButton(
          icon: Icon(_obscureConfirm
              ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: const Color(0xFFAAAAAA)),
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
        )),
      ),
      const SizedBox(height: 20),
      _buildButton('Reset Password', _resetPassword),
    ]);

  // ── Success UI ─────────────────────────────────────────────────────────────
  Widget _buildSuccessContent() => Column(children: [
    Container(width: 72, height: 72,
      decoration: const BoxDecoration(color: Color(0xFF16a34a), shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, size: 40, color: Colors.white)),
    const SizedBox(height: 16),
    Text('Password Reset!', style: GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0A2342))),
    const SizedBox(height: 8),
    Text('You can now log in with your new password.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, height: 50,
      child: ElevatedButton(
        onPressed: () => context.go('/login'),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A6FA8),
            foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text('Back to Login',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
      )),
  ]);

  Widget _buildButton(String label, VoidCallback onTap) =>
    SizedBox(width: double.infinity, height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A6FA8),
            foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: _isLoading
            ? const SizedBox(height: 22, width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700)),
      ));

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFBBBBBB)),
    prefixIcon: Icon(icon, size: 18, color: const Color(0xFF1A6FA8)),
    filled: true, fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1A6FA8), width: 2)),
  );
}
