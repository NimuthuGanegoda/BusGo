import 'package:flutter/material.dart';
import 'package:busgo_scanner/screens/domino_splash_screen.dart';
import 'package:busgo_scanner/screens/busgo_logo_splash_screen.dart';

class SplashWrapper extends StatefulWidget {
  final Widget child; // The main app (e.g., your login screen or main shell)
  const SplashWrapper({super.key, required this.child});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  int _phase = 0; // 0 = domino, 1 = BUSGO logo, 2 = main app

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case 0:
        return DominoSplashScreen(
          onComplete: () => setState(() => _phase = 1),
        );
      case 1:
        return BusgoLogoSplashScreen(
          onComplete: () => setState(() => _phase = 2),
        );
      default:
        return widget.child;
    }
  }
}
