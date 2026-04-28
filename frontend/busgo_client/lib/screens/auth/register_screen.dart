import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
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

  // ── High-contrast colors for dark background ───────────────────────────────
  static const _labelColor    = Color(0xFF9DBFE0);  // light blue-white
  static const _inputText     = Color(0xFFEEEEEE);  // near white
  static const _hintColor     = Color(0xFF6A8AAA);  // medium blue-gray
  static const _fieldBg       = Color(0xFF1A2535);  // dark blue-tinted bg
  static const _fieldBorder   = Color(0xFF2A4060);  // subtle border
  static const _errorColor    = Color(0xFFFF7B7B);  // bright red
  static const _headerTitle   = Color(0xFFE0EEF8);  // bright white-blue
  static const _headerSub     = Color(0xFF7A9AB8);  // muted blue
  static const _sectionTitle  = Color(0xFF4FC3F7);  // accent blue

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

    final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (_emailController.text.trim().isEmpty)
      _errors['email'] = 'Email is required';
    else if (!emailRegex.hasMatch(_emailController.text.trim()))
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
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3050),
                          shape: BoxShape.circle,
                          border: Border.all(color: _fieldBorder),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_back,
                            size: 16, color: _labelColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Create Account',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _headerTitle)),
                        Text('Join BUSGO today',
                            style: TextStyle(
                                fontSize: 11, color: _headerSub)),
                      ]),
                  ]),
                  const SizedBox(height: 16),

                  // ── Progress bar ───────────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: const Color(0xFF1A2535),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4FC3F7)),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Form fields ────────────────────────────────────────────
                  _buildField(
                    label:      'Full Name',
                    hint:       'Enter your full name',
                    icon:       Icons.person_rounded,
                    iconColor:  const Color(0xFF5B9BD5),
                    controller: _fullNameController,
                    error:      _errors['fullName'],
                  ),
                  _buildField(
                    label:       'Email Address',
                    hint:        'Enter your email',
                    icon:        Icons.email_rounded,
                    iconColor:   const Color(0xFF66BB6A),
                    controller:  _emailController,
                    error:       _errors['email'],
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildField(
                    label:      'Username',
                    hint:       'Choose a username',
                    icon:       Icons.alternate_email_rounded,
                    iconColor:  const Color(0xFFBA68C8),
                    controller: _usernameController,
                    error:      _errors['username'],
                  ),
                  _buildField(
                    label:       'Phone Number',
                    hint:        'Enter phone number',
                    icon:        Icons.phone_rounded,
                    iconColor:   const Color(0xFF4DB6AC),
                    controller:  _phoneController,
                    error:       _errors['phone'],
                    keyboardType: TextInputType.phone,
                  ),
                  _buildField(
                    label:       'Date of Birth (optional)',
                    hint:        'YYYY-MM-DD (e.g. 1995-03-25)',
                    icon:        Icons.calendar_month_rounded,
                    iconColor:   const Color(0xFFFF8A65),
                    controller:  _dobController,
                    keyboardType: TextInputType.datetime,
                  ),
                  _buildField(
                    label:      'Password',
                    hint:       'Min. 8 characters',
                    icon:       Icons.lock_rounded,
                    iconColor:  const Color(0xFFFFCC02),
                    controller: _passwordController,
                    error:      _errors['password'],
                    isPassword: true,
                    obscure:    _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  _buildField(
                    label:      'Confirm Password',
                    hint:       'Re-enter password',
                    icon:       Icons.lock_rounded,
                    iconColor:  const Color(0xFFEF5350),
                    controller: _confirmPasswordController,
                    error:      _errors['confirmPassword'],
                    isPassword: true,
                    obscure:    _obscureConfirm,
                    onToggleObscure: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),

                  // ── Server error ───────────────────────────────────────────
                  if (auth.errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.warning_amber,
                            size: 14, color: _errorColor),
                        const SizedBox(width: 6),
                        Expanded(child: Text(auth.errorMessage!,
                            style: const TextStyle(
                                fontSize: 12, color: _errorColor))),
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

                      if (_dobController.text.trim().isNotEmpty) {
                        final dobRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                        if (!dobRegex.hasMatch(_dobController.text.trim())) {
                          setState(() => _errors['dob'] =
                              'Use format YYYY-MM-DD (e.g. 1995-03-25)');
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
                        // Navigate to email verification screen
                        context.push(
                          '/verify-email',
                          extra: _emailController.text.trim(),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Sign in link ───────────────────────────────────────────
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Already have an account? ',
                        style: TextStyle(
                            fontSize: 12, color: _hintColor)),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text('Sign In',
                          style: TextStyle(
                              fontSize: 12,
                              color: _sectionTitle,
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
    final color    = iconColor ?? _labelColor;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _labelColor)),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
          color: hasError
              ? const Color(0xFF2A1A1A)
              : _fieldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: hasError ? _errorColor.withOpacity(0.5) : _fieldBorder,
              width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller:   controller,
            obscureText:  isPassword && obscure,
            keyboardType: keyboardType,
            onChanged:    (_) => setState(() {}),
            // ← HIGH CONTRAST: white text on dark field
            style: const TextStyle(
                fontSize: 13,
                color:    _inputText,
                fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              hintText:  hint,
              hintStyle: const TextStyle(
                  fontSize: 12, color: _hintColor),
              border:          InputBorder.none,
              isDense:         true,
              contentPadding:  const EdgeInsets.symmetric(vertical: 10),
            ),
          )),
          if (isPassword && onToggleObscure != null)
            GestureDetector(
              onTap: onToggleObscure,
              child: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16, color: _hintColor),
            ),
        ]),
      ),
      if (hasError) ...[
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.warning_amber, size: 12, color: _errorColor),
          const SizedBox(width: 4),
          Text(error,
              style: const TextStyle(
                  fontSize: 11, color: _errorColor)),
        ]),
      ],
      const SizedBox(height: 10),
    ]);
  }
}



