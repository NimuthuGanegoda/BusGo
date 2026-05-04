import 'package:flutter/material.dart';
import '../widgets/drift_splash_screen.dart';
import '../widgets/busgo_splash.dart';

class SplashWrapper extends StatefulWidget {
  final Widget child;
  const SplashWrapper({super.key, required this.child});
  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  int _phase = 0; // 0=drift, 1=BUSGO, 2=main app

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case 0:
        return DriftSplashScreen(
          onComplete: () => setState(() => _phase = 1),
        );
      case 1:
        return Scaffold(
          backgroundColor: const Color(0xFF0B0E1A),
          body: BusgoSplashScreen(
            subtitle: 'S  C  A  N  N  E  R',
            onDone: () => setState(() => _phase = 2),
          ),
        );
      default:
        return widget.child;
    }
  }
}


