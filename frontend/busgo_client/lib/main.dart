import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/bus_provider.dart';
import 'providers/emergency_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/user_provider.dart';
import 'routes/app_router.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/bus_service.dart';
import 'services/emergency_service.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'services/rating_service.dart';
import 'services/token_service.dart';
import 'services/trip_service.dart';
import 'services/user_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> _requestLocationPermission() async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  } catch (e) {
    debugPrint('[main] Location permission error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Request GPS permission at startup
  await _requestLocationPermission();

  // Local preferences
  await LocalStorageService.init();

  // Supabase — used for Realtime bus-location broadcasts
  await Supabase.initialize(
    url:     AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // ── Initialise local notifications ────────────────────────────────────────
  await NotificationService.instance.init();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const BusGoApp());
}

class BusGoApp extends StatelessWidget {
  const BusGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tokenService     = TokenService();
    final apiClient        = ApiClient(tokenService);
    final authService      = AuthService(apiClient, tokenService);
    final userService      = UserService(apiClient);
    final busService       = BusService(apiClient);
    final tripService      = TripService(apiClient);
    final ratingService    = RatingService(apiClient);
    final emergencyService = EmergencyService(apiClient);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService, tokenService),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(userService),
        ),
        ChangeNotifierProvider(
          create: (_) => BusProvider(busService),
        ),
        ChangeNotifierProvider(
          create: (_) => TripProvider(tripService, ratingService),
        ),
        ChangeNotifierProvider(
          create: (_) => EmergencyProvider(emergencyService),
        ),
      ],
      child: MaterialApp.router(
        title:                    'BUSGO Client',
        debugShowCheckedModeBanner: false,
        theme:                    AppTheme.lightTheme,
        routerConfig:             appRouter,
      ),
    );
  }
}



