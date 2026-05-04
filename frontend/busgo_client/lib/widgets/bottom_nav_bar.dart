import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const AppBottomNavBar({super.key, required this.currentIndex, required this.onTap});

  static const _accent = Color(0xFF4ECDC4);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: _accent.withOpacity(0.08), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, -2)),
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(children: [
              _navItem(0, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.public_rounded, 'Map'),
              _navItem(2, Icons.search_rounded, 'Search'),
              _navItem(3, Icons.person_rounded, 'Profile'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = currentIndex == index;
    final activeColor = _accent;
    final inactiveColor = Colors.white.withOpacity(0.35);

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, isActive ? -6 : 0, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive ? activeColor.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: isActive ? activeColor : inactiveColor),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                height: isActive ? 16 : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isActive ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(label, style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: activeColor, letterSpacing: 0.3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}









