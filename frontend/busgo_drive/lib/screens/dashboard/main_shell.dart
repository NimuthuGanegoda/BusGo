import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'route_map_screen.dart';
import '../emergency/emergency_screen.dart';
import 'my_rating_screen.dart';
import '../profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  void switchToTab(int index) => setState(() => _currentIndex = index);

  final List<Widget> _screens = const [
    DashboardScreen(),
    RouteMapScreen(),
    EmergencyScreen(),
    MyRatingScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _currentIndex, children: _screens),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [Color(0xFF0B1A2E), Color(0xFF132F54), Color(0xFF1E5AA8)],
      )),
      child: SafeArea(child: SizedBox(height: 68,
        child: Row(children: [
          _navItem(0, Icons.home_rounded,                 'Dashboard'),
          _navItem(1, Icons.map_rounded,                  'Map'),
          _navItem(2, Icons.notifications_active_rounded, 'Alerts'),
          _navItem(3, Icons.star_rounded,                 'Rating'),
          _navItem(4, Icons.person_rounded,               'Profile'),
        ]),
      )),
    ),
  );

  Widget _navItem(int index, IconData icon, String label) {
    final isActive      = _currentIndex == index;
    final activeColor   = index == 2
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF64B5F6);
    final inactiveColor = Colors.white.withValues(alpha: 0.45);

    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 22, color: isActive ? activeColor : inactiveColor),
        const SizedBox(height: 3),
        Text(label, style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : inactiveColor)),
        if (isActive) ...[
          const SizedBox(height: 3),
          Container(width: 6, height: 6,
              decoration: BoxDecoration(
                  color: activeColor, shape: BoxShape.circle)),
        ],
      ]),
    ));
  }
}