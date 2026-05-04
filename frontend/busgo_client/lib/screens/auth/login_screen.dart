import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/busgo_alert.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  double _offset = 0.0;
  late ScrollController _scrollController;

  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  bool  _obscure    = true;

  static const _teal = Color(0xFF4ECDC4);
  static const _navy = Color(0xFF111B29);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() => _offset = _scrollController.offset);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      context.read<UserProvider>().setUser(auth.currentUser!);
      context.go('/home');
    } else {
      final e = auth.errorMessage ?? '';
      String title = 'Login Failed', msg = 'Something went wrong.';
      if (e == 'LOGIN_RESTRICTED')                       { title = 'Access Denied';   msg = 'Not authorised for this app.'; }
      else if (e.contains('verify'))                     { title = 'Verify Email';     msg = 'Please verify your email.'; }
      else if (e.contains('invalid') || e.contains('401')) {                           msg = 'Invalid email or password.'; }
      else if (e == 'ACCOUNT_LOCKED')                    { title = 'Account Locked';   msg = 'Too many attempts. Try in 15 min.'; }
      else if (e.contains('socket') || e.contains('timeout')) { title = 'No Connection'; msg = 'Cannot reach server.'; }
      else if (e.isNotEmpty)                             { msg = e; }
      BusgoAlert.show(context, type: BusgoAlertType.error, title: title, message: msg);
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight  = MediaQuery.of(context).size.height;
    final scrollPercent = (_offset / (screenHeight * 0.7)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF111B29),
      body: Stack(children: [

        // ── 1. FIXED PARALLAX BACKGROUND ─────────────────────────────────
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1200,
              height: 800,
              child: Stack(children: [

                // Sky
                _layer('assets/images/scene/sky.jpg',      0.10),
                // Background mountains
                _layer('assets/images/scene/mountBg.png',  0.20),
                // Mid mountains
                _layer('assets/images/scene/mountMg.png',  0.40),
                // Cloud 2 (behind foreground)
                _layer('assets/images/scene/cloud2.png',   0.50),

                // "RIDE WITH US" — fades out as user scrolls
                _buildSceneText(
                  'RIDE WITH US',
                  Colors.white,
                  opacity: (1.0 - scrollPercent * 2.5).clamp(0.0, 1.0),
                  yOffset: -50 * scrollPercent,
                ),

                // Foreground mountains — moves fastest
                _layer('assets/images/scene/mountFg.png',  0.70),
                // Cloud 1
                _layer('assets/images/scene/cloud1.png',   0.80),
                // Cloud 3
                _layer('assets/images/scene/cloud3.png',   0.65),

                // White plug — stays pinned to mountFg bottom
                Transform.translate(
                  offset: Offset(0, 800 - (_offset * 0.70)),
                  child: Container(
                    width: 1200, height: 1200,
                    color: const Color(0xFF0A1628)),
                ),

                // Fog gradient — blends mountains into the dark card
                Transform.translate(
                  offset: Offset(0, 600 - (_offset * 0.70)),
                  child: Container(
                    width: 1200, height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0A1628).withOpacity(0),
                          const Color(0xFF0A1628),
                        ])),
                  ),
                ),

                // "WELCOME BACK" — revealed through the fog
                _buildSceneText(
                  'WELCOME',
                  _teal,
                  opacity: ((scrollPercent - 0.4) * 2.5).clamp(0.0, 1.0),
                  yOffset: 20 * (1 - scrollPercent),
                ),

                // Down arrow (fades out as user scrolls)
                Positioned(
                  top: 320,
                  left: 0, right: 0,
                  child: Opacity(
                    opacity: (1.0 - scrollPercent * 3).clamp(0.0, 1.0),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Scroll to Sign In',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70, fontSize: 14,
                            letterSpacing: 1.5)),
                        SizedBox(height: 8),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70, size: 36),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── 2. SCROLLABLE LOGIN CONTENT ───────────────────────────────────
        SingleChildScrollView(
          controller: _scrollController,
          child: Column(children: [

            // Spacer — lets parallax animate before card appears
            SizedBox(height: screenHeight * 0.88),

            // Login card
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0A1628),
                borderRadius: BorderRadius.only(
                  topLeft:  Radius.circular(32),
                  topRight: Radius.circular(32))),
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
              child: Consumer<AuthProvider>(
                builder: (_, auth, __) => Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Handle bar
                      Center(child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(2)))),

                      // Heading
                      Text('Welcome back',
                        style: GoogleFonts.poppins(
                          fontSize: 26, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Sign in to continue your journey',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.40))),

                      const SizedBox(height: 28),

                      // Email
                      _field(
                        ctrl: _emailCtrl,
                        hint: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email required';
                          if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
                              .hasMatch(v.trim())) return 'Enter a valid email';
                          return null;
                        }),

                      const SizedBox(height: 14),

                      // Password
                      _field(
                        ctrl: _passCtrl,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        suffix: _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffix: () => setState(() => _obscure = !_obscure),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password required';
                          if (v.length < 8) return 'Minimum 8 characters';
                          return null;
                        }),

                      const SizedBox(height: 10),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => context.push('/forgot-password'),
                          child: Text('Forgot Password?',
                            style: GoogleFonts.poppins(
                              fontSize: 12, color: _teal,
                              fontWeight: FontWeight.w500)))),

                      const SizedBox(height: 24),

                      // Sign In button
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: !auth.isLoading
                                ? const LinearGradient(colors: [Color(0xFF3BBFB8), _teal])
                                : null,
                            color: auth.isLoading ? _teal.withOpacity(0.3) : null,
                            boxShadow: auth.isLoading ? null : [
                              BoxShadow(color: _teal.withOpacity(0.35),
                                  blurRadius: 16, offset: const Offset(0, 5))]),
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _doLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                            child: auth.isLoading
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white))
                                : Text('Sign In', style: GoogleFonts.poppins(
                                    fontSize: 15, fontWeight: FontWeight.w700,
                                    color: Colors.white))))),

                      const SizedBox(height: 16),

                      // Divider
                      Row(children: [
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.09))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.white.withOpacity(0.30)))),
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.09))),
                      ]),

                      const SizedBox(height: 16),

                      // Create account
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: OutlinedButton(
                          onPressed: () => context.push('/register'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _teal.withOpacity(0.45), width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                          child: Text('Create Account', style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: _teal)))),
                    ])))),
          ]),
        ),
      ]),
    );
  }

  // Parallax layer — matches Gemini's _parallaxLayer exactly
  Widget _layer(String asset, double speed) {
    return Transform.translate(
      offset: Offset(0, -(_offset * speed)),
      child: Image.asset(asset,
        width: 1200, height: 800,
        fit: BoxFit.cover,
        gaplessPlayback: true),
    );
  }

  // Scene text — matches Gemini's _buildText exactly
  Widget _buildSceneText(String text, Color color,
      {required double opacity, required double yOffset}) {
    return Center(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, yOffset),
          child: Text(text,
            style: GoogleFonts.montserrat(
              color: color, fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              shadows: const [Shadow(
                  color: Color(0x44000000),
                  blurRadius: 12, offset: Offset(0, 2))])))));
  }

  // Form field
  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    IconData? suffix,
    VoidCallback? onSuffix,
    bool obscure = false,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
            fontSize: 13, color: Colors.white.withOpacity(0.25)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        prefixIcon: Icon(icon, size: 18,
            color: const Color(0xFF4ECDC4).withOpacity(0.65)),
        suffixIcon: suffix != null
            ? GestureDetector(
                onTap: onSuffix,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(suffix, size: 18, color: Colors.white38)))
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4ECDC4), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
        errorStyle: GoogleFonts.poppins(
            fontSize: 11, color: const Color(0xFFFF9999))));
  }
}


