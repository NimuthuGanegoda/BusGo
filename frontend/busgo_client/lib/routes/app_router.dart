import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/map/live_map_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/search/route_search_screen.dart';
import '../screens/alerts/alerts_screen.dart';
import '../screens/passenger/notifications_screen.dart';
import '../screens/emergency/emergency_screen.dart';
import '../screens/qr/qr_card_screen.dart';
import '../screens/rating/driver_rating_screen.dart';
import '../screens/history/ride_history_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../widgets/rating_popup.dart';
import '../screens/payment/payment_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) => VerifyEmailScreen(
        email: state.extra as String? ?? '',
      ),
    ),
    GoRoute(
      path: '/payment',
      builder: (context, state) => const PaymentScreen(),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return _MainShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              builder: (context, state) => const LiveMapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const RouteSearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: '/alerts',
      builder: (context, state) => const AlertsScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/emergency',
      builder: (context, state) => const EmergencyScreen(),
    ),
    GoRoute(
      path: '/qr',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return QrCardScreen(
          alightingStopId:   extra?['alighting_stop_id'] as String?,
          alightingStopName: extra?['alighting_stop_name'] as String?,
        );
      },
    ),
    
    GoRoute(
      path: '/rating',
      builder: (context, state) => const DriverRatingScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const RideHistoryScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
  ],
);

// ── Main shell widget ─────────────────────────────────────────────────────────
class _MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const _MainShell({required this.navigationShell});
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  bool    _watchingStarted = false;
  bool    _dialogShowing   = false;
  String? _lastShownTripId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryStartWatching();
  }

  void _tryStartWatching() {
    if (_watchingStarted) return;
    final auth = context.read<AuthProvider>();
    final trip = context.read<TripProvider>();
    if (auth.currentUser != null && auth.currentUser!.id.isNotEmpty) {
      trip.startWatchingTrips(auth.currentUser!.id);
      _watchingStarted = true;
      debugPrint('[MainShell] Started watching trips for ${auth.currentUser!.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, tripProvider, child) {
        final pendingTrip = tripProvider.completedTripForRating;

        if (pendingTrip != null &&
            !_dialogShowing &&
            pendingTrip.id != _lastShownTripId) {
          _dialogShowing   = true;
          _lastShownTripId = pendingTrip.id;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            tripProvider.clearCompletedTrip();
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => RatingPopup(trip: pendingTrip),
            ).then((_) {
              _dialogShowing = false;
            });
          });
        }

        return Scaffold(
          body: widget.navigationShell,
          bottomNavigationBar: AppBottomNavBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: (index) => widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            ),
          ),
        );
      },
    );
  }
}










