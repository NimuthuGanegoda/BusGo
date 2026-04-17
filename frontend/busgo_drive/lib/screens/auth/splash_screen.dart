import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/token_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final token = await TokenService().getAccess();
    if (!mounted) return;
    context.go(token != null ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primary,
    body: const Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.directions_bus_rounded, size: 80, color: Colors.white),
        SizedBox(height: 16),
        Text('BUSGO', style: TextStyle(color: Colors.white,
            fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 4)),
        SizedBox(height: 8),
        Text('Drive', style: TextStyle(color: Colors.white70, fontSize: 18)),
        SizedBox(height: 40),
        CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
      ],
    )),
  );
}
