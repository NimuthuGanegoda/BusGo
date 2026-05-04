import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/scanner_api_service.dart';
import 'login_screen.dart';
import 'scanner_terms_screen.dart';
import 'scanner_privacy_screen.dart';
import 'scanner_help_screen.dart';

class ScannerProfileScreen extends StatefulWidget {
  final ScannerApiService api;
  const ScannerProfileScreen({super.key, required this.api});
  @override
  State<ScannerProfileScreen> createState() => _ScannerProfileScreenState();
}

class _ScannerProfileScreenState extends State<ScannerProfileScreen> {
  static const _bg = Color(0xFF040A14);
  static const _surface = Color(0xFF0A1628);
  static const _cyan = Color(0xFF3FEFEF);
  static const _cardColor = Color(0x331E1E1E);
  static const _border = Color(0x1AFFFFFF);

  bool _loggingOut = false;
  bool _scanSound = true;
  bool _haptic = true;
  bool _flashlight = false;

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('End Session', style: GoogleFonts.inter(
            color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout and end your scanning session?',
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout', style: GoogleFonts.inter(
                color: const Color(0xFFE74C3C), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await widget.api.logout();
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _surface.withOpacity(0.95),
              border: Border(bottom: BorderSide(color: _cyan.withOpacity(0.1))),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.person_rounded, color: _cyan, size: 22),
              ),
              const SizedBox(width: 14),
              Text('Profile', style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const SizedBox(height: 10),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cyan.withOpacity(0.1),
                    border: Border.all(color: _cyan.withOpacity(0.3), width: 2),
                    boxShadow: [BoxShadow(color: _cyan.withOpacity(0.15), blurRadius: 20)],
                  ),
                  child: Icon(Icons.qr_code_scanner_rounded, size: 36, color: _cyan),
                ),
                const SizedBox(height: 14),
                Text('Scanner Operator', style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cyan.withOpacity(0.2)),
                  ),
                  child: Text('BUSGO Scanner', style: GoogleFonts.inter(
                      fontSize: 11, color: _cyan, fontWeight: FontWeight.w600, letterSpacing: 1)),
                ),
                const SizedBox(height: 30),

                _sectionTitle('SETTINGS'),
                const SizedBox(height: 10),
                _menuCard(children: [
                  _menuItem(icon: Icons.volume_up_rounded, label: 'Scan Sound',
                      trailing: _buildToggle(_scanSound, (v) => setState(() => _scanSound = v))),
                  _divider(),
                  _menuItem(icon: Icons.vibration_rounded, label: 'Haptic Feedback',
                      trailing: _buildToggle(_haptic, (v) => setState(() => _haptic = v))),
                  _divider(),
                  _menuItem(icon: Icons.flash_on_rounded, label: 'Flashlight',
                      trailing: _buildToggle(_flashlight, (v) => setState(() => _flashlight = v))),
                ]),

                const SizedBox(height: 20),

                _sectionTitle('INFORMATION'),
                const SizedBox(height: 10),
                _menuCard(children: [
                  _menuItem(icon: Icons.info_outline_rounded, label: 'App Version',
                      trailing: Text('v2.0.0', style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.white38))),
                  _divider(),
                  _menuItem(icon: Icons.description_outlined, label: 'Terms of Service',
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ScannerTermsScreen()))),
                  _divider(),
                  _menuItem(icon: Icons.shield_outlined, label: 'Privacy Policy',
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ScannerPrivacyScreen()))),
                  _divider(),
                  _menuItem(icon: Icons.help_outline_rounded, label: 'Help & Support',
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ScannerHelpScreen()))),
                ]),

                const SizedBox(height: 20),

                _sectionTitle('SESSION'),
                const SizedBox(height: 10),
                _menuCard(children: [
                  _menuItem(
                    icon: Icons.logout_rounded,
                    label: 'End Session & Logout',
                    iconColor: const Color(0xFFE74C3C),
                    labelColor: const Color(0xFFE74C3C),
                    trailing: _loggingOut
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE74C3C)))
                        : const Icon(Icons.chevron_right, color: Color(0xFFE74C3C), size: 20),
                    onTap: _loggingOut ? null : _handleLogout,
                  ),
                ]),

                const SizedBox(height: 30),
                Text('BUSGO Scanner v2.0.0', style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white24, letterSpacing: 0.5)),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: Colors.white38, letterSpacing: 1.5)),
    ),
  );

  Widget _menuCard({required List<Widget> children}) => Container(
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
    ),
    child: Column(children: children),
  );

  Widget _menuItem({
    required IconData icon, required String label,
    Widget? trailing, Color? iconColor, Color? labelColor, VoidCallback? onTap,
  }) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: (iconColor ?? _cyan).withOpacity(0.1),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 18, color: iconColor ?? _cyan),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: labelColor ?? Colors.white))),
        if (trailing != null) trailing!,
      ]),
    ),
  );

  Widget _divider() => Divider(height: 1, color: _border, indent: 64);

  Widget _buildToggle(bool value, ValueChanged<bool> onChanged) => GestureDetector(
    onTap: () => onChanged(!value),
    child: Container(
      width: 44, height: 24,
      decoration: BoxDecoration(
        color: value ? _cyan.withOpacity(0.2) : const Color(0xFF2C3E50),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(2),
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: value ? _cyan : const Color(0xFF555555),
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}









