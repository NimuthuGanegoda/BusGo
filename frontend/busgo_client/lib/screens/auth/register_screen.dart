import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController        = TextEditingController();
  final _emailController           = TextEditingController();
  final _usernameController        = TextEditingController();
  final _phoneController           = TextEditingController();
  final _dobController             = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;

  final Map<String, String?> _errors = {};

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate() {
    _errors.clear();
    if (_fullNameController.text.trim().isEmpty)
      _errors['fullName'] = 'Full name is required';
    if (_emailController.text.trim().isEmpty)
      _errors['email'] = 'Email is required';
    else if (!_emailController.text.contains('@'))
      _errors['email'] = 'Enter a valid email address';
    if (_usernameController.text.trim().isEmpty)
      _errors['username'] = 'Username is required';
    else if (_usernameController.text.trim().length < 3)
      _errors['username'] = 'Username must be at least 3 characters';
    if (_phoneController.text.trim().isEmpty)
      _errors['phone'] = 'Phone number is required';
    if (_passwordController.text.isEmpty)
      _errors['password'] = 'Password is required';
    else if (_passwordController.text.length < 8)
      _errors['password'] = 'Password must be at least 8 characters';
    if (_confirmPasswordController.text.isEmpty)
      _errors['confirmPassword'] = 'Please confirm your password';
    else if (_confirmPasswordController.text != _passwordController.text)
      _errors['confirmPassword'] = 'Passwords do not match';
    setState(() {});
    return _errors.isEmpty;
  }

  double get _progress {
    int filled = 0;
    if (_fullNameController.text.isNotEmpty) filled++;
    if (_emailController.text.isNotEmpty) filled++;
    if (_usernameController.text.isNotEmpty) filled++;
    if (_phoneController.text.isNotEmpty) filled++;
    if (_passwordController.text.isNotEmpty) filled++;
    if (_confirmPasswordController.text.isNotEmpty) filled++;
    return filled / 6;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────────────────
                  Row(children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(
                            color: AppColors.headerBg, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_back,
                            size: 14, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create Account', style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                        Text('Join BUSGO today', style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                      ]),
                  ]),
                  const SizedBox(height: 16),

                  // ── Progress bar ───────────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.secondary),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Form fields ────────────────────────────────────────────
                  _buildField(
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    icon: Icons.person_rounded,
                    iconColor: const Color(0xFF1E5AA8),
                    controller: _fullNameController,
                    error: _errors['fullName'],
                  ),
                  _buildField(
                    label: 'Email Address',
                    hint: 'Enter your email',
                    icon: Icons.email_rounded,
                    iconColor: const Color(0xFF2E7D32),
                    controller: _emailController,
                    error: _errors['email'],
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildField(
                    label: 'Username',
                    hint: 'Choose a username',
                    icon: Icons.alternate_email_rounded,
                    iconColor: const Color(0xFF9C27B0),
                    controller: _usernameController,
                    error: _errors['username'],
                  ),
                  _buildField(
                    label: 'Phone Number',
                    hint: 'Enter phone number',
                    icon: Icons.phone_rounded,
                    iconColor: const Color(0xFF00897B),
                    controller: _phoneController,
                    error: _errors['phone'],
                    keyboardType: TextInputType.phone,
                  ),
                  _buildField(
                    label: 'Date of Birth (optional)',
                    hint: 'YYYY-MM-DD (e.g. 1995-03-25)',
                    icon: Icons.calendar_month_rounded,
                    iconColor: const Color(0xFFE65100),
                    controller: _dobController,
                    keyboardType: TextInputType.datetime,
                  ),
                  _buildField(
                    label: 'Password',
                    hint: 'Min. 8 characters',
                    icon: Icons.lock_rounded,
                    iconColor: const Color(0xFFF57F17),
                    controller: _passwordController,
                    error: _errors['password'],
                    isPassword: true,
                    obscure: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  _buildField(
                    label: 'Confirm Password',
                    hint: 'Re-enter password',
                    icon: Icons.lock_rounded,
                    iconColor: const Color(0xFFD32F2F),
                    controller: _confirmPasswordController,
                    error: _errors['confirmPassword'],
                    isPassword: true,
                    obscure: _obscureConfirm,
                    onToggleObscure: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),

                  // ── Server error ───────────────────────────────────────────
                  if (auth.errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.warning_amber,
                            size: 12, color: AppColors.danger),
                        const SizedBox(width: 4),
                        Expanded(child: Text(auth.errorMessage!,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.danger))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // ── Register button ────────────────────────────────────────
                  PrimaryButton(
                    text: 'Register',
                    isLoading: auth.isLoading,
                    onPressed: () async {
                      auth.clearError();
                      if (!_validate()) return;
                      // Validate date of birth format if provided
                      if (_dobController.text.trim().isNotEmpty) {
                        final dobRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                        if (!dobRegex.hasMatch(_dobController.text.trim())) {
                          setState(() => _errors['dob'] = 'Use format YYYY-MM-DD (e.g. 1995-03-25)');
                          return;
                        }
                      }

                      final success = await auth.register(
                        fullName:    _fullNameController.text.trim(),
                        email:       _emailController.text.trim(),
                        username:    _usernameController.text.trim(),
                        phone:       _phoneController.text.trim(),
                        password:    _passwordController.text,
                        dateOfBirth: _dobController.text.trim().isNotEmpty
                            ? _dobController.text.trim()
                            : null,
                      );
                      if (success && mounted) {
                        context.read<UserProvider>().setUser(auth.currentUser!);
                        GoRouter.of(context).go('/home');
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── Sign in link ───────────────────────────────────────────
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Already have an account? ',
                        style: TextStyle(fontSize: 12,
                            color: AppColors.textMuted)),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text('Sign In',
                          style: TextStyle(fontSize: 12,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    Color? iconColor,
    String? error,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
  }) {
    final hasError = error != null;
    final color    = iconColor ?? AppColors.textMuted;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          fontSize: 11, color: AppColors.textMuted)),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: hasError ? const Color(0xFFFFF5F5) : AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: hasError ? AppColors.danger : AppColors.border,
              width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller:    controller,
            obscureText:   isPassword && obscure,
            keyboardType:  keyboardType,
            onChanged:     (_) => setState(() {}),
            style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          )),
          if (isPassword && onToggleObscure != null)
            GestureDetector(
              onTap: onToggleObscure,
              child: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 16, color: AppColors.textMuted),
            ),
        ]),
      ),
      if (hasError) ...[
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.warning_amber, size: 12, color: AppColors.danger),
          const SizedBox(width: 4),
          Text(error, style: const TextStyle(
              fontSize: 11, color: AppColors.danger)),
        ]),
      ],
      const SizedBox(height: 10),
    ]);
  }
}