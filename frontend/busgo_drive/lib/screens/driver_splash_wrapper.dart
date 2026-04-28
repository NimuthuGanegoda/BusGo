import 'package:flutter/material.dart';
import 'kitkat_splash_screen.dart';
import 'busgo_driver_logo_splash.dart';

class DriverSplashWrapper extends StatefulWidget {
  final Widget child;
  const DriverSplashWrapper({super.key, required this.child});

  @override
  State<DriverSplashWrapper> createState() => _DriverSplashWrapperState();
}

class _DriverSplashWrapperState extends State<DriverSplashWrapper> {
  int _phase = 0;

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case 0:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: KitkatSplashScreen(
            onComplete: () => setState(() => _phase = 1),
          ),
        );
      case 1:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: BusgoDriverLogoSplash(
            onComplete: () => setState(() => _phase = 2),
          ),
        );
      default:
        return widget.child;
    }
  }
}



