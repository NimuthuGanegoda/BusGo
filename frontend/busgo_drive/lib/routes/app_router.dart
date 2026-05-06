import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/recovery_pin_screen.dart';
import '../screens/dashboard/main_shell.dart';
import '../screens/profile/profile_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (c, s) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (c, s) => const RegisterScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (c, s) => const ForgotPasswordScreen()),
    GoRoute(
      path: '/recovery-pin',
      builder: (c, s) => RecoveryPinScreen(
        pin: s.extra as String? ?? '')),
    GoRoute(
      path: '/dashboard',
      builder: (c, s) => const MainShell()),
    GoRoute(
      path: '/profile',
      builder: (c, s) => const ProfileScreen()),
  ],
);