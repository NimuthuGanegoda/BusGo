import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/scanner_api_service.dart';
import 'active_scanner_screen.dart';
import 'scanner_profile_screen.dart';

class ScannerMainShell extends StatefulWidget {
  final ScannerApiService api;
  const ScannerMainShell({super.key, required this.api});
  @override
  State<ScannerMainShell> createState() => _ScannerMainShellState();
}

class _ScannerMainShellState extends State<ScannerMainShell> {
  int _currentIndex = 0;

  static const _cyan = Color(0xFF3FEFEF);
  static const _red = Color(0xFFE74C3C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040A14),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ActiveScannerScreen(api: widget.api),
          ScannerProfileScreen(api: widget.api),
        ],
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF040A14),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 8),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: _cyan.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: _cyan.withOpacity(0.06),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, -2),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _navItem(0, Icons.qr_code_scanner_rounded, 'Scanner'),
                  _navItem(1, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    final activeColor = _cyan;
    final inactiveColor = Colors.white.withOpacity(0.3);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive ? activeColor.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: isActive ? activeColor : inactiveColor),
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
                        fontSize: 11, fontWeight: FontWeight.w600,
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






