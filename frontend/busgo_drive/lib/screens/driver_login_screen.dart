import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/busgo_alert.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = false;

  late final AnimationController _sunAnim;
  late final AnimationController _mountainAnim;
  late final AnimationController _treesBackAnim;
  late final AnimationController _treesFrontAnim;
  late final AnimationController _birdAnim;
  late final AnimationController _birdWingAnim;
  late final AnimationController _roadAnim;
  late final AnimationController _formEntrance;

  TextStyle _poppins({double size = 14, FontWeight weight = FontWeight.w400, Color color = Colors.white}) =>
      GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);

  @override
  void initState() {
    super.initState();
    _sunAnim = AnimationController(vsync: this, duration: const Duration(seconds: 60))..forward();
    _mountainAnim = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
    _treesBackAnim = AnimationController(vsync: this, duration: const Duration(seconds: 25))..repeat();
    _treesFrontAnim = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _birdAnim = AnimationController(vsync: this, duration: const Duration(seconds: 30))..forward();
    _birdWingAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _roadAnim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _formEntrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  }

  @override
  void dispose() {
    _sunAnim.dispose(); _mountainAnim.dispose(); _treesBackAnim.dispose();
    _treesFrontAnim.dispose(); _birdAnim.dispose(); _birdWingAnim.dispose();
    _roadAnim.dispose(); _formEntrance.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    if (!_formKey.currentState!.validate()) return;

    final success = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;

    if (success) {
      BusgoAlert.show(context, type: BusgoAlertType.success, title: 'Welcome!', message: 'You have been logged in successfully.');
      _sunAnim.stop(); _mountainAnim.stop(); _treesBackAnim.stop();
      _treesFrontAnim.stop(); _birdAnim.stop(); _birdWingAnim.stop(); _roadAnim.stop();
      context.go('/dashboard');
    } else {
      final error = auth.error ?? '';
      if (error == 'LOGIN_RESTRICTED') {
        BusgoAlert.show(context, type: BusgoAlertType.error, title: 'Access Denied', message: 'This account is not authorized to use this app.');
      } else if (error == 'INVALID_CREDENTIALS') {
        BusgoAlert.show(context, type: BusgoAlertType.error, title: 'Login Failed', message: 'Invalid email or password. Please try again.');
      } else if (error == 'TOO_MANY_REQUESTS') {
        BusgoAlert.show(context, type: BusgoAlertType.warning, title: 'Slow Down', message: 'Too many attempts. Please wait a moment and try again.');
      } else if (error == 'CONNECTION_FAILED') {
        BusgoAlert.show(context, type: BusgoAlertType.warning, title: 'Connection Error', message: 'Could not reach the server. Check your connection.');
      } else if (error == 'ACCOUNT_LOCKED') {
        BusgoAlert.show(context,
          type: BusgoAlertType.error,
          title: 'Account Locked',
          message: 'Too many failed attempts. Try again in 15 minutes.',
        );
      } else if (error == 'PENDING_APPROVAL') {
        BusgoAlert.show(context,
          type: BusgoAlertType.warning,
          title: 'Pending Approval',
          message: 'Your account is awaiting admin approval.',
        );

      } else {
        BusgoAlert.show(context, type: BusgoAlertType.error, title: 'Login Failed', message: error.isNotEmpty ? error : 'Something went wrong. Please try again.');
      }
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        AnimatedBuilder(animation: _sunAnim, builder: (context, _) {
          final t = _sunAnim.value;
          return Container(width: double.infinity, height: double.infinity, decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
              Color.lerp(const Color(0xFF1A0533), const Color(0xFF0D001A), t)!,
              Color.lerp(const Color(0xFF6B2FA0), const Color(0xFF2D1050), t)!,
              Color.lerp(const Color(0xFFE87D3E), const Color(0xFF8B3A1A), t)!,
              Color.lerp(const Color(0xFFF5A623), const Color(0xFFC46A10), t)!,
            ], stops: const [0.0, 0.35, 0.65, 1.0])));
        }),
        AnimatedBuilder(animation: _sunAnim, builder: (context, _) {
          final sunY = screenH * 0.12 + (_sunAnim.value * screenH * 0.35);
          return Positioned(right: screenW * 0.15, top: sunY, child: Container(width: 70, height: 70,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF5A623), boxShadow: [
              BoxShadow(color: const Color(0xFFF5A623).withOpacity(0.6), blurRadius: 40, spreadRadius: 15),
              BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.3), blurRadius: 80, spreadRadius: 30)])));
        }),
        Positioned(bottom: screenH * 0.42, left: 0, right: 0, child: AnimatedBuilder(animation: _mountainAnim,
          builder: (context, _) => CustomPaint(size: Size(screenW, 120), painter: _MountainPainter(progress: _mountainAnim.value)))),
        Positioned(bottom: screenH * 0.38, left: 0, right: 0, child: AnimatedBuilder(animation: _treesBackAnim,
          builder: (context, _) => CustomPaint(size: Size(screenW, 60), painter: _TreesPainter(progress: _treesBackAnim.value, color: const Color(0xFF3D1A6E), treeHeight: 55, density: 12)))),
        Positioned(bottom: screenH * 0.36, left: 0, right: 0, child: AnimatedBuilder(animation: _roadAnim,
          builder: (context, _) => CustomPaint(size: Size(screenW, 28), painter: _RoadPainter(progress: _roadAnim.value)))),
        Positioned(bottom: screenH * 0.33, left: 0, right: 0, child: AnimatedBuilder(animation: _treesFrontAnim,
          builder: (context, _) => CustomPaint(size: Size(screenW, 80), painter: _TreesPainter(progress: _treesFrontAnim.value, color: const Color(0xFF1A0A30), treeHeight: 75, density: 8)))),
        AnimatedBuilder(animation: Listenable.merge([_birdAnim, _birdWingAnim]), builder: (context, _) {
          return Stack(children: List.generate(5, (i) {
            final startX = screenW * (0.6 + i * 0.08);
            final birdX = startX - (_birdAnim.value * screenW * 1.5);
            final birdY = screenH * (0.12 + i * 0.035) + sin(i * 1.5) * 15;
            if (birdX < -30 || birdX > screenW + 30) return const SizedBox.shrink();
            return Positioned(left: birdX, top: birdY, child: SizedBox(width: (8 + i * 0.5) * 3, height: (8 + i * 0.5) * 2,
              child: CustomPaint(painter: _BirdPainter(wingFlap: (_birdWingAnim.value - 0.5) * (8 + i * 0.5) * 0.8, size: 8 + i * 0.5))));
          }));
        }),
        Positioned(bottom: 0, left: 0, right: 0, height: screenH * 0.38, child: Container(color: const Color(0xFF1A0A30))),
        Positioned(bottom: 0, left: 0, right: 0, child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _formEntrance, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic))),
          child: FadeTransition(opacity: CurvedAnimation(parent: _formEntrance, curve: const Interval(0.3, 1, curve: Curves.easeOut)), child: _buildLoginForm()))),
      ]),
    );
  }

  Widget _buildLoginForm() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
        child: Container(
          padding: const EdgeInsets.fromLTRB(35, 30, 35, 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.15),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5))]),
          child: Consumer<AuthProvider>(builder: (context, auth, _) {
            return Form(key: _formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Login', style: _poppins(size: 38, weight: FontWeight.w700)),
              const SizedBox(height: 28),
              _buildPillField(controller: _emailCtrl, hint: 'Email Address', icon: Icons.person, keyboardType: TextInputType.emailAddress,
                validator: (v) { if (v == null || v.trim().isEmpty) return 'Email is required'; if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email'; return null; }),
              const SizedBox(height: 24),
              _buildPillField(controller: _passCtrl, hint: 'Password', icon: _obscure ? Icons.visibility_off : Icons.visibility, obscure: true,
                onIconTap: () => setState(() => _obscure = !_obscure),
                validator: (v) { if (v == null || v.isEmpty) return 'Password is required'; if (v.length < 8) return 'Minimum 8 characters'; return null; }),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(onTap: () => setState(() => _remember = !_remember), child: Row(children: [
                  Container(width: 15, height: 15, decoration: BoxDecoration(
                    color: _remember ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white.withOpacity(_remember ? 1 : 0.4), width: 1.5)),
                    child: _remember ? const Icon(Icons.check, size: 10, color: Color(0xFF0a2862)) : null),
                  const SizedBox(width: 6),
                  Text('Remember me', style: _poppins(size: 12, color: Colors.white.withOpacity(0.8)))])),
                GestureDetector(onTap: () => context.push('/forgot-password'),
                  child: Text('Forgot Password?', style: _poppins(size: 12, weight: FontWeight.w500)))]),
              const SizedBox(height: 20),
              GestureDetector(onTap: auth.isLoading ? null : _handleLogin,
                child: Container(width: double.infinity, height: 50, decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]),
                  alignment: Alignment.center,
                  child: auth.isLoading
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0a2862))),
                        const SizedBox(width: 10), Text('Signing in...', style: _poppins(size: 16, weight: FontWeight.w600, color: const Color(0xFF0a2862)))])
                    : Text('Login', style: _poppins(size: 16, weight: FontWeight.w600, color: const Color(0xFF0a2862))))),
              const SizedBox(height: 24),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => context.push('/register'),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text("Don't have an account? ", style: _poppins(size: 13, color: Colors.white54)),
                  Text('Register', style: _poppins(size: 13, color: Colors.white, weight: FontWeight.w600)),
                ]),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ])));
          }))));
  }

  Widget _buildPillField({required TextEditingController controller, required String hint, required IconData icon,
      bool obscure = false, VoidCallback? onIconTap, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(controller: controller, obscureText: obscure && _obscure, keyboardType: keyboardType, validator: validator,
      style: _poppins(size: 16, color: Colors.white),
      decoration: InputDecoration(hintText: hint, hintStyle: _poppins(size: 16, color: Colors.white.withOpacity(0.5)),
        filled: true, fillColor: Colors.transparent, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        suffixIcon: GestureDetector(onTap: onIconTap, child: Padding(padding: const EdgeInsets.only(right: 18),
          child: Icon(icon, size: 18, color: Colors.white.withOpacity(0.7)))),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.white.withOpacity(0.5), width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2)),
        errorStyle: _poppins(size: 11, color: const Color(0xFFFF6B6B))));
  }
}

class _MountainPainter extends CustomPainter {
  final double progress; _MountainPainter({required this.progress});
  @override void paint(Canvas canvas, Size size) {
    _draw(canvas, size, progress, const Color(0xFF5C3D8F), 0.7, 20);
    _draw(canvas, size, progress * 1.3 % 1.0, const Color(0xFF3D1A6E), 1.0, 0);
  }
  void _draw(Canvas canvas, Size size, double p, Color color, double hf, double yo) {
    final paint = Paint()..color = color; final path = Path(); path.moveTo(0, size.height);
    final sw = size.width / 3; final offset = p * sw * 2;
    for (int i = -2; i < 6; i++) { final x = i * sw - offset; final ph = size.height * (0.3 + (sin(i * 2.1 + 0.5) * 0.3 + 0.3)) * hf;
      path.lineTo(x, size.height - yo); path.lineTo(x + sw * 0.5, size.height - ph - yo); }
    path.lineTo(size.width + 100, size.height); path.close(); canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(_MountainPainter old) => old.progress != progress;
}

class _TreesPainter extends CustomPainter {
  final double progress; final Color color; final double treeHeight; final int density;
  _TreesPainter({required this.progress, required this.color, required this.treeHeight, required this.density});
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color; final tw = size.width / density; final offset = progress * tw * 2;
    for (int i = -2; i < density + 4; i++) { final x = i * tw * 1.5 - offset; final h = treeHeight * (0.6 + sin(i * 1.7) * 0.4);
      canvas.drawPath(Path()..moveTo(x, size.height)..lineTo(x + tw * 0.4, size.height - h)..lineTo(x + tw * 0.8, size.height)..close(), paint);
      canvas.drawRect(Rect.fromLTWH(x + tw * 0.35, size.height - 8, tw * 0.1, 8), paint); }
  }
  @override bool shouldRepaint(_TreesPainter old) => old.progress != progress;
}

class _RoadPainter extends CustomPainter {
  final double progress; _RoadPainter({required this.progress});
  @override void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF2A2A2A));
    final ep = Paint()..color = const Color(0xFF444444)..strokeWidth = 1;
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), ep);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), ep);
    final dp = Paint()..color = const Color(0xFFF5A623)..strokeWidth = 2;
    const dw = 20.0, gw = 15.0; final t = dw + gw; final o = progress * t;
    double x = -t + o; while (x < size.width) { final s = x.clamp(0.0, size.width); final e = (x + dw).clamp(0.0, size.width);
      if (e > s) canvas.drawLine(Offset(s, size.height / 2), Offset(e, size.height / 2), dp); x += t; }
  }
  @override bool shouldRepaint(_RoadPainter old) => old.progress != progress;
}

class _BirdPainter extends CustomPainter {
  final double wingFlap; final double size; _BirdPainter({required this.wingFlap, required this.size});
  @override void paint(Canvas canvas, Size cs) {
    final p = Paint()..color = const Color(0xFF1A0A30)..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final cx = cs.width / 2, cy = cs.height / 2;
    canvas.drawPath(Path()..moveTo(cx, cy)..quadraticBezierTo(cx - size, cy + wingFlap, cx - size * 1.5, cy + wingFlap * 1.3), p);
    canvas.drawPath(Path()..moveTo(cx, cy)..quadraticBezierTo(cx + size, cy + wingFlap, cx + size * 1.5, cy + wingFlap * 1.3), p);
  }
  @override bool shouldRepaint(_BirdPainter old) => old.wingFlap != wingFlap;
}



