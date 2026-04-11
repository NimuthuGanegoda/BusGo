import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_theme.dart';
import 'screens/login_screen.dart';

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
      home:                     const LoginScreen(),
    );
  }
}
