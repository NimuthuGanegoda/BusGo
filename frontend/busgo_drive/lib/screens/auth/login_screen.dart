import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  double _offset = 0.0;
  late ScrollController _scrollController;

  final _formKey              = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _passwordController   = TextEditingController();
  bool _obscurePassword = true;

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
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(AuthProvider auth) async {
    auth.clearError();
    if (!_formKey.currentState!.validate()) return;
    final router  = GoRouter.of(context);
    final success = await auth.login(
        _employeeIdController.text.trim(), _passwordController.text);
    if (success && mounted) router.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight  = MediaQuery.of(context).size.height;
    final scrollPercent = (_offset / (screenHeight * 0.7)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF111B29),
      body: Stack(children: [

        // ── FIXED PARALLAX BACKGROUND ──────────────────────────────────────
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

                _sceneText('DRIVE WITH US', Colors.white,
                  opacity: (1.0 - scrollPercent * 2.5).clamp(0.0, 1.0),
                  yOffset: -50 * scrollPercent),

                _layer('assets/images/scene/mountFg.png', 0.70),
                _layer('assets/images/scene/cloud1.png',  0.80),
                _layer('assets/images/scene/cloud3.png',  0.65),

                Transform.translate(
                  offset: Offset(0, 800 - (_offset * 0.70)),
                  child: Container(width: 1200, height: 1200,
                      color: const Color(0xFF0A2342))),

                Transform.translate(
                  offset: Offset(0, 600 - (_offset * 0.70)),
                  child: Container(
                    width: 1200, height: 220,
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [const Color(0xFF0A2342).withOpacity(0),
                               const Color(0xFF0A2342)]))),
                ),

                _sceneText('DRIVER PORTAL', const Color(0xFF64B5F6),
                  opacity: ((scrollPercent - 0.4) * 2.5).clamp(0.0, 1.0),
                  yOffset: 20 * (1 - scrollPercent), size: 36),

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

        // ── SCROLLABLE LOGIN CONTENT ────────────────────────────────────────
        SingleChildScrollView(
          controller: _scrollController,
          child: Column(children: [
            SizedBox(height: screenHeight * 0.88),

            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0A2342),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32))),
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
              child: Consumer<AuthProvider>(builder: (ctx, auth, _) =>
                Form(key: _formKey, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Handle bar
                  Center(child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2)))),

                  // ── Logo row — official BUSGO logo ──────────────────────
                  Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/busgo-logo-new.jpeg',
                        width: 44, height: 44, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.directions_bus_rounded,
                              size: 22, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('BUSGO', style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 3)),
                      Text('DRIVER PORTAL', style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFF90CAF9),
                        letterSpacing: 2)),
                    ]),
                  ]),

                  const SizedBox(height: 24),

                  Text('Welcome back', style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Sign in to your driver account', style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withOpacity(0.45))),

                  const SizedBox(height: 20),

                  // Error banner
                  if (auth.error != null) Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(auth.error!, style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.redAccent))),
                    ])),

                  // Email field
                  _field(ctrl: _employeeIdController, hint: 'driver@busgo.lk',
                    icon: Icons.person_outline,
                    validator: (v) => v == null || v.isEmpty ? 'Email is required' : null),
                  const SizedBox(height: 14),

                  // Password field
                  _field(ctrl: _passwordController, hint: 'Password',
                    icon: Icons.lock_outline, obscure: _obscurePassword,
                    suffix: _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    onSuffix: () => setState(() => _obscurePassword = !_obscurePassword),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'Minimum 6 characters';
                      return null;
                    }),

                  const SizedBox(height: 22),

                  // ── Sign In button ────────────────────────────────────────
                  SizedBox(width: double.infinity, height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: !auth.isLoading
                            ? const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF64B5F6)])
                            : null,
                        color: auth.isLoading
                            ? const Color(0xFF1565C0).withOpacity(0.4) : null,
                        boxShadow: auth.isLoading ? null : [
                          BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.30),
                              blurRadius: 14, offset: const Offset(0, 5))]),
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : () => _handleLogin(auth),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                        child: auth.isLoading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : Text('Sign In', style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: Colors.white))))),

                  const SizedBox(height: 14),

                  // ── Register — proper button widget ───────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/register'),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: Text('New Driver? Register Here',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFD54F),
                        side: const BorderSide(
                            color: Color(0xFFFFD54F), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Forgot password
                  Center(child: GestureDetector(
                    onTap: () => context.push('/forgot-password'),
                    child: Text('Forgot password?',
                      style: GoogleFonts.inter(fontSize: 12,
                          color: const Color(0xFF64B5F6),
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFF64B5F6))))),
                ])),
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
              color: color, fontSize: size,
              fontWeight: FontWeight.w900, letterSpacing: 1,
              shadows: const [Shadow(color: Color(0x44000000),
                  blurRadius: 12, offset: Offset(0, 2))]),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 13, color: Colors.white.withOpacity(0.28)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(icon, size: 18,
            color: const Color(0xFF64B5F6).withOpacity(0.65)),
        suffixIcon: suffix != null
            ? GestureDetector(
                onTap: onSuffix,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(suffix, size: 18, color: Colors.white38),
                ),
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.09)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        errorStyle: GoogleFonts.inter(
            fontSize: 11, color: const Color(0xFFFF9999)),
      ),
    );
  }
}
