import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/splash_wrapper.dart';  // ← ADD THIS LINE

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const BusgoScannerApp());
}

class BusgoScannerApp extends StatelessWidget {
  const BusgoScannerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'BUSGO Scanner',
      debugShowCheckedModeBanner: false,
      theme:                    AppTheme.light,
      home:                     const SplashWrapper(child: LoginScreen()),  // ← CHANGE THIS LINE
    );
  }
}
