import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // Focus nodes for border highlight
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _emailFocused = false;
  bool _passwordFocused = false;

  // Animation
  late AnimationController _animController;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();

    _emailFocus.addListener(() => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordFocused = _passwordFocus.hasFocus));

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnims = List.generate(4, (i) {
      final start = i * 0.1;
      final end = start + 0.35;
      return CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
      );
    });

    _slideAnims = List.generate(4, (i) {
      final start = i * 0.1;
      final end = start + 0.35;
      return Tween<Offset>(
        begin: const Offset(0, 16),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
      ));
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  TextStyle _inter({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1A2E),
              Color(0xFF132F54),
              Color(0xFF1E5AA8),
            ],
          ),
        ),
        child: Stack(
        children: [
          // ── Main content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // ── TOP SECTION: Icon + BUSGO ──
                  _buildAnimated(0, _buildTopSection()),

                  const SizedBox(height: 20),

                  // ── WELCOME TEXT ──
                  _buildAnimated(1, _buildWelcomeText()),

                  const SizedBox(height: 16),

                  // ── WHITE FORM CARD ──
                  _buildAnimated(2, _buildFormCard()),

                  const SizedBox(height: 20),

                  // ── DIVIDER + SOCIAL + REGISTER ──
                  _buildAnimated(3, _buildBottomSection()),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAnimated(int index, Widget child) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return Opacity(
          opacity: _fadeAnims[index].value,
          child: Transform.translate(
            offset: _slideAnims[index].value,
            child: child,
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // TOP SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildTopSection() {
    return Column(
      children: [
        // App logo
        Image.asset(
          'assets/images/buslogo.jpeg',
          width: 120,
          height: 120,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1E5AA8),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E5AA8).withValues(alpha: 0.4),
                    offset: const Offset(0, 8),
                    blurRadius: 28,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.directions_bus_rounded, size: 36, color: Colors.white),
            );
          },
        ),
        const SizedBox(height: 16),
        // BUSGO text
        Text(
          'BUSGO',
          style: _inter(
            size: 42,
            weight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 8.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 44,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        // Tagline
        Text(
          'Smart Bus Travel, Simplified',
          style: _inter(
            size: 13,
            weight: FontWeight.w400,
            color: const Color(0xFF8AAFD4),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // WELCOME TEXT
  // ═══════════════════════════════════════════════════════
  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Welcome back 👋',
          style: _inter(size: 13, color: const Color(0xFF5BB8F5)),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign In',
          style: _inter(size: 26, weight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Opacity(
          opacity: 0.8,
          child: Text(
            'Access your BusGo account',
            style: _inter(size: 12, color: const Color(0xFF8AAFD4)),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // WHITE FORM CARD
  // ═══════════════════════════════════════════════════════
  Widget _buildFormCard() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: const Border(
              top: BorderSide(color: Color(0xFF1A6FA8), width: 3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.24),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: const Color(0xFF1A6FA8).withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Email field ──
                Text(
                  'EMAIL ADDRESS',
                  style: _inter(
                    size: 10,
                    weight: FontWeight.w600,
                    color: const Color(0xFF888888),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  isFocused: _emailFocused,
                  icon: Icons.email_outlined,
                  hint: 'neo@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Password field ──
                Text(
                  'PASSWORD',
                  style: _inter(
                    size: 10,
                    weight: FontWeight.w600,
                    color: const Color(0xFF888888),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  isFocused: _passwordFocused,
                  icon: Icons.lock_outline,
                  hint: '••••••••',
                  obscure: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8) {
                      return 'Minimum 8 characters';
                    }
                    return null;
                  },
                ),

                // Server error
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, size: 14, color: Color(0xFFE53935)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: _inter(size: 11, color: const Color(0xFFE53935)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // ── Remember me + Forgot Password ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: _rememberMe
                                  ? const Color(0xFF1A6FA8)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _rememberMe
                                    ? const Color(0xFF1A6FA8)
                                    : const Color(0xFFCCCCCC),
                                width: 1.5,
                              ),
                            ),
                            child: _rememberMe
                                ? const Icon(Icons.check, size: 12, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Remember me',
                            style: _inter(size: 12, color: const Color(0xFF555555)),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/forgot-password'),
                      child: Text(
                        'Forgot Password?',
                        style: _inter(
                          size: 12,
                          weight: FontWeight.w600,
                          color: const Color(0xFF1A6FA8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Login button ──
                _buildLoginButton(auth),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // TEXT FIELD
  // ═══════════════════════════════════════════════════════
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required IconData icon,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure && _obscurePassword,
      keyboardType: keyboardType,
      validator: validator,
      style: _inter(size: 13, color: const Color(0xFF333333)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _inter(size: 13, color: const Color(0xFFBBBBBB)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 18, color: const Color(0xFF1A6FA8)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: obscure
            ? GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: _obscurePassword
                        ? const Color(0xFFAAAAAA)
                        : const Color(0xFF1A6FA8),
                  ),
                ),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A6FA8), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
        ),
        errorStyle: _inter(size: 11, color: const Color(0xFFE53935)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // LOGIN BUTTON
  // ═══════════════════════════════════════════════════════
  Widget _buildLoginButton(AuthProvider auth) {
    return GestureDetector(
      onTap: auth.isLoading
          ? null
          : () async {
              auth.clearError();
              if (!_formKey.currentState!.validate()) return;

              final success = await auth.login(
                _emailController.text.trim(),
                _passwordController.text,
              );
              if (success && mounted) {
                context.read<UserProvider>().setUser(auth.currentUser!);
                GoRouter.of(context).go('/home');
              }
            },
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF1A6FA8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A6FA8).withValues(alpha: 0.4),
              offset: const Offset(0, 6),
              blurRadius: 20,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: auth.isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Signing in...',
                    style: _inter(size: 15, weight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              )
            : Text(
                'Login →',
                style: _inter(size: 15, weight: FontWeight.w700, color: Colors.white),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // BOTTOM SECTION: Divider, Social, Register
  // ═══════════════════════════════════════════════════════
  Widget _buildBottomSection() {
  return Column(
    children: [
      Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFEEEEEE), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('or continue with',
                style: _inter(size: 11, color: const Color(0xFFAAAAAA))),
          ),
          const Expanded(child: Divider(color: Color(0xFFEEEEEE), thickness: 1)),
        ],
      ),
      const SizedBox(height: 14),
      // Google only
      GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Sign-In coming soon!'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          height: 42, width: double.infinity,
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1)),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('G', style: _inter(size: 14,
                weight: FontWeight.w700, color: const Color(0xFF4285F4))),
            Text(' Continue with Google',
                style: _inter(size: 12, color: const Color(0xFF444444))),
          ]),
        ),
      ),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("Don't have an account?",
            style: _inter(size: 12, color: const Color(0xFF777777))),
        GestureDetector(
          onTap: () => context.push('/register'),
          child: Text(' Register', style: _inter(size: 12,
              weight: FontWeight.w700, color: const Color(0xFF1A6FA8))),
        ),
      ]),
    ],
  );
}
  Widget _buildSocialButton(String icon, String label, Color iconColor) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            icon,
            style: _inter(size: 14, weight: FontWeight.w700, color: iconColor),
          ),
          Text(
            ' $label',
            style: _inter(size: 12, color: const Color(0xFF444444)),
          ),
        ],
      ),
    );
  }
}
