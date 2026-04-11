import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/scanner_api_service.dart';
import 'active_scanner_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool  _obscure    = true;
  bool  _loading    = false;
  String? _error;

  // Shared service instance — will be passed to scanner screen
  final _tokenService = ScannerTokenService();
  late  final ScannerApiService _api;

  @override
  void initState() {
    super.initState();
    _api = ScannerApiService(_tokenService);
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    if (await _tokenService.hasSession()) {
      try {
        // Validate session by fetching profile
        if (!mounted) return;
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ActiveScannerScreen(api: _api)));
      } catch (_) {
        await _tokenService.clear();
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleStartSession() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await _api.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => ActiveScannerScreen(api: _api)));
    } catch (e) {
      setState(() {
        _error   = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0A2342), Color(0xFF0F3460), Color(0xFF0A2342)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 30),
                  _buildCard(),
                  const SizedBox(height: 20),
                  Text(
                    'BUSGO Scanner v2.0.0',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.4),
            blurRadius: 20, offset: const Offset(0, 8),
          )],
        ),
        child: const Icon(Icons.qr_code_scanner_rounded, size: 36, color: Colors.white),
      ),
      const SizedBox(height: 14),
      RichText(text: TextSpan(
        style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4),
        children: const [
          TextSpan(text: 'BUS', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'GO', style: TextStyle(color: AppColors.lightBlue)),
        ],
      )),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('SCANNER', style: GoogleFonts.inter(
          fontSize: 13, letterSpacing: 3, fontWeight: FontWeight.w700,
          color: const Color(0xFF90CAF9),
        )),
      ),
    ],
  );

  Widget _buildCard() => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(22),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Start Session', style: GoogleFonts.inter(
              fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF0A2342),
            )),
            const SizedBox(height: 4),
            Text('Sign in to begin scanning passengers', style: GoogleFonts.inter(
              fontSize: 15, color: const Color(0xFF5A6477),
            )),
            const SizedBox(height: 24),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            _label('EMAIL'),
            const SizedBox(height: 8),
            _field(ctrl: _emailCtrl, hint: 'driver@busgo.lk', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 18),

            _label('PASSWORD'),
            const SizedBox(height: 8),
            _field(ctrl: _passCtrl, hint: 'Enter password', icon: Icons.lock_outline_rounded, isPassword: true),
            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleStartSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: const Color(0xFF93C5FD),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.qr_code_scanner_rounded, size: 22),
                        const SizedBox(width: 10),
                        Text('Start Scanning Session', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text('Forgot password? Contact admin', style: GoogleFonts.inter(
              fontSize: 14, color: const Color(0xFF1565C0), fontWeight: FontWeight.w600,
            ))),
          ],
        ),
      ),
    ),
  );

  Widget _label(String text) => Text(text, style: GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w700,
    color: const Color(0xFF3D4A5C), letterSpacing: 0.8,
  ));

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: ctrl,
    obscureText: isPassword && _obscure,
    keyboardType: keyboardType,
    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF1A1D26)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 15, color: const Color(0xFFA0A8B4)),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(icon, size: 22, color: const Color(0xFF8A94A6)),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 48),
      suffixIcon: isPassword ? Padding(
        padding: const EdgeInsets.only(right: 4),
        child: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 22, color: const Color(0xFF8A94A6)),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ) : null,
      filled: true, fillColor: const Color(0xFFF5F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDDE2E8), width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDDE2E8), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
    ),
    validator: (v) {
      if (v == null || v.isEmpty) return 'This field is required';
      if (isPassword && v.length < 6) return 'Minimum 6 characters';
      return null;
    },
  );
}
