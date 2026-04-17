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
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _passwordController   = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _employeeIdController.dispose(); _passwordController.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity, height: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0A2342), Color(0xFF0D2E5C)],
      )),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(children: [
          const SizedBox(height: 60),
          _buildLogo(),
          const SizedBox(height: 36),
          _buildLoginCard(),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/register'),
            child: RichText(text: TextSpan(children: [
              TextSpan(text: 'New driver? ', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF90CAF9))),
              TextSpan(text: 'Register here →', style: GoogleFonts.inter(fontSize: 12,
                  fontWeight: FontWeight.w700, color: const Color(0xFFFFD54F))),
            ])),
          ),
          const SizedBox(height: 40),
        ]),
      )),
    ),
  );

  Widget _buildLogo() => Column(children: [
    Container(width: 72, height: 72,
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.directions_bus_rounded, size: 36, color: Colors.white)),
    const SizedBox(height: 16),
    RichText(text: TextSpan(style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 3), children: const [
      TextSpan(text: 'BUS', style: TextStyle(color: Colors.white)),
      TextSpan(text: 'GO',  style: TextStyle(color: Color(0xFF64B5F6))),
    ])),
    const SizedBox(height: 4),
    Text('DRIVER PORTAL', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF90CAF9), letterSpacing: 2)),
  ]);

  Widget _buildLoginCard() => Consumer<AuthProvider>(builder: (context, auth, _) =>
    Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome back', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text('Sign in to your driver account', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9E9E9E))),
        const SizedBox(height: 22),
        if (auth.error != null) Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(child: Text(auth.error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
          ]),
        ),
        _buildLabel('EMAIL ADDRESS'),
        const SizedBox(height: 6),
        _buildInputField(controller: _employeeIdController, hint: 'driver@busgo.lk',
            icon: Icons.person_outline,
            validator: (v) => v == null || v.isEmpty ? 'Driver ID is required' : null),
        const SizedBox(height: 16),
        _buildLabel('PASSWORD'),
        const SizedBox(height: 6),
        _buildInputField(controller: _passwordController, hint: 'Enter password',
            icon: Icons.lock_outline, isPassword: true,
            validator: (v) { if (v == null || v.isEmpty) return 'Password is required';
                             if (v.length < 6) return 'Minimum 6 characters'; return null; }),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : () => _handleLogin(auth),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: auth.isLoading
                ? const SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text('Login', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 14),
        Center(child: Text('Forgot password? Contact admin',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryLight))),
      ])),
    ),
  );

  Widget _buildLabel(String text) => Text(text, style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF757575), letterSpacing: 0.8));

  Widget _buildInputField({
    required TextEditingController controller, required String hint,
    required IconData icon, bool isPassword = false, String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller, obscureText: isPassword && _obscurePassword,
    validator: validator,
    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF424242)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFBDBDBD)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFFBDBDBD)),
      suffixIcon: isPassword ? IconButton(
        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18, color: const Color(0xFFBDBDBD)),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ) : null,
      filled: true, fillColor: const Color(0xFFF5F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger)),
    ),
  );

  Future<void> _handleLogin(AuthProvider auth) async {
    auth.clearError();
    if (!_formKey.currentState!.validate()) return;
    final router = GoRouter.of(context);
    final success = await auth.login(_employeeIdController.text.trim(), _passwordController.text);
    if (success && mounted) router.go('/dashboard');
  }
}
