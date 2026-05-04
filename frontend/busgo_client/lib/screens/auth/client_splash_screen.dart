import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/busgo_splash.dart';
import '../../widgets/drift_splash_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int  _phase     = 0; // 0=drift, 1=BUSGO, 2=navigate
  bool _authDone  = false;
  bool _animDone  = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    await auth.checkSession();
    if (!mounted) return;
    _isLoggedIn = auth.isLoggedIn && auth.currentUser != null;
    if (_isLoggedIn && auth.currentUser != null) {
      context.read<UserProvider>().setUser(auth.currentUser!);
    }
    _authDone = true;
    _maybeNavigate();
  }

  void _maybeNavigate() {
    if (!_animDone || !_authDone) return;
    if (!mounted) return;
    if (_isLoggedIn) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case 0:
        return DriftSplashScreen(
          onComplete: () {
            if (mounted) setState(() => _phase = 1);
          },
        );
      case 1:
        return Scaffold(
          backgroundColor: const Color(0xFF0B0E1A),
          body: BusgoSplashScreen(
            subtitle: 'C  L  I  E  N  T',
            onDone: () {
              if (!mounted) return;
              setState(() {
                _animDone = true;
                _phase = 2;
              });
              _maybeNavigate();
            },
          ),
        );
      default:
        // Waiting for auth while showing dark screen
        return const Scaffold(
          backgroundColor: Color(0xFF0B0E1A),
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4ECDC4),
              strokeWidth: 2,
            ),
          ),
        );
    }
  }
}



