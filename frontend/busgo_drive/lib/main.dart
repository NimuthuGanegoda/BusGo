import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/drive_providers.dart';
import 'routes/app_router.dart';
import 'services/api_client.dart';
import 'services/drive_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const BusGoDriveApp());
}

class BusGoDriveApp extends StatelessWidget {
  const BusGoDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Service graph
    final tokenService  = DriveTokenService();
    final apiClient     = DriveApiClient(tokenService);
    final authService   = DriveAuthService(apiClient, tokenService);
    final driverService = DriveDriverService(apiClient);
    final emergencyService = DriveEmergencyService(apiClient);
    final notifService  = DriveNotificationService(apiClient);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DriveAuthProvider(authService, tokenService),
        ),
        ChangeNotifierProvider(
          create: (_) => DriveDriverProvider(driverService),
        ),
        ChangeNotifierProvider(
          create: (_) => DriveEmergencyProvider(emergencyService),
        ),
        Provider<DriveNotificationService>(create: (_) => notifService),
      ],
      child: MaterialApp.router(
        title:                    'BusGo Drive',
        debugShowCheckedModeBanner: false,
        theme:                    AppTheme.light,
        routerConfig:             appRouter,
      ),
    );
  }
}
