import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

/// Shown after registration — user enters the 6-digit PIN
/// sent to their email to verify it is real.
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isLoading  = false;
  bool _isResending = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _pin =>
      _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_pin.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit PIN');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    final auth    = context.read<AuthProvider>();
    final success = await auth.verifyEmail(widget.email, _pin);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      context.read<UserProvider>().setUser(auth.currentUser!);
      GoRouter.of(context).go('/home');
    } else {
      setState(() => _error = auth.errorMessage ?? 'Invalid PIN. Please try again.');
      auth.clearError();
      // Clear PIN fields on failure
      for (final c in _controllers) c.clear();
      _focusNodes.first.requestFocus();
    }
  }

  Future<void> _resend() async {
    setState(() { _isResending = true; _error = null; });
    final auth    = context.read<AuthProvider>();
    final success = await auth.resendVerificationPin(widget.email);
    if (!mounted) return;
    setState(() => _isResending = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new PIN has been sent to your email.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } else {
      setState(() => _error = auth.errorMessage ?? 'Failed to resend PIN.');
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Back button ──────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3A5C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF1A6FA8).withOpacity(0.3))),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ── Email icon ───────────────────────────────────────────────
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A6FA8).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF1A6FA8).withOpacity(0.4),
                      width: 2),
                ),
                child: const Icon(Icons.mark_email_unread_rounded,
                    size: 38, color: Color(0xFF5BB8F5)),
              ),
              const SizedBox(height: 24),

              // ── Title ────────────────────────────────────────────────────
              Text('Verify Your Email',
                  style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 10),
              Text(
                'We sent a 6-digit PIN to',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: const Color(0xFF8AAFD4)),
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5BB8F5)),
              ),
              const SizedBox(height: 36),

              // ── PIN input boxes ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  return Container(
                    width: 46, height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3A5C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _error != null
                            ? const Color(0xFFE53935).withOpacity(0.7)
                            : const Color(0xFF1A6FA8).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _controllers[i],
                      focusNode:  _focusNodes[i],
                      textAlign:  TextAlign.center,
                      maxLength:  1,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      decoration: const InputDecoration(
                        border:         InputBorder.none,
                        counterText:    '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        }
                        if (value.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        // Auto-verify when all 6 digits entered
                        if (_pin.length == 6) _verify();
                        setState(() => _error = null);
                      },
                    ),
                  );
                }),
              ),

              // ── Error message ────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: Color(0xFFE53935)),
                  const SizedBox(width: 6),
                  Text(_error!,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFFE53935))),
                ]),
              ],
              const SizedBox(height: 32),

              // ── Verify button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A6FA8),
                    disabledBackgroundColor:
                        const Color(0xFF1A6FA8).withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Verify Email',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Resend PIN ───────────────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Didn't receive it? ",
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF8AAFD4))),
                GestureDetector(
                  onTap: _isResending ? null : _resend,
                  child: _isResending
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF5BB8F5)))
                      : Text('Resend PIN',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF5BB8F5))),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}









