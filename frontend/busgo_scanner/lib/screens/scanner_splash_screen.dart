import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/busgo_splash.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E1A),
      body: BusgoSplashScreen(
        subtitle: 'S  C  A  N  N  E  R',
        onDone: () {
          if (mounted) context.go('/scan');
        },
      ),
    );
  }
}

