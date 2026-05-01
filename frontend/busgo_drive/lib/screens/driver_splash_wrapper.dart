import 'package:flutter/material.dart';
import '../widgets/drift_splash_screen.dart';
import '../widgets/busgo_splash.dart';

class DriverSplashWrapper extends StatefulWidget {
  final Widget child;
  const DriverSplashWrapper({super.key, required this.child});
  @override
  State<DriverSplashWrapper> createState() => _DriverSplashWrapperState();
}

class _DriverSplashWrapperState extends State<DriverSplashWrapper> {
  int _phase = 0; // 0=drift, 1=BUSGO, 2=main app

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case 0:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: DriftSplashScreen(
            onComplete: () => setState(() => _phase = 1),
          ),
        );
      case 1:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF0B0E1A),
            body: BusgoSplashScreen(
              subtitle: 'D  R  I  V  E  R',
              onDone: () => setState(() => _phase = 2),
            ),
          ),
        );
      default:
        return widget.child;
    }
  }
}
