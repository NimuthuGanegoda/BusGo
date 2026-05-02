import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'terms_screen.dart';
import 'privacy_screen.dart';
import 'help_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _bg = Color(0xFF040A14);
  static const _card = Color(0xFF0A1628);
  static const _border = Color(0x1AFFFFFF);
  static const _cyan = Color(0xFF4ECDC4);
  static const _textSec = Color(0xFF6F767E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadPreferences();
      context.read<UserProvider>().fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Consumer<UserProvider>(builder: (context, userProvider, _) {
        final user = userProvider.user;
        return SingleChildScrollView(child: Column(children: [
          // Profile Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: _card,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
            child: SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(children: [
                const Align(alignment: Alignment.centerLeft, child: Text('My Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                const SizedBox(height: 20),
                Container(width: 100, height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_cyan, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: _cyan.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                  alignment: Alignment.center,
                  child: Text(user?.initials ?? '?', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700))),
                const SizedBox(height: 14),
                Text(user?.fullName ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text(user?.email ?? '', style: const TextStyle(fontSize: 13, color: _textSec)),
                if (user?.phone != null && user!.phone!.isNotEmpty)
                  Text(user.phone!, style: const TextStyle(fontSize: 12, color: _textSec)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text((user?.isActive ?? false) ? '● Active Member' : '○ Inactive',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: (user?.isActive ?? false) ? _cyan : _textSec))),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    _buildStat('TRIPS', '${user?.totalTrips ?? 0}'),
                    _statDivider(),
                    _buildStat('MEMBER', user?.memberSince ?? 'N/A'),
                    _statDivider(),
                    _buildStat('TYPE', user?.membershipType ?? 'Standard'),
                  ])),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => context.push('/edit-profile'),
                  style: ElevatedButton.styleFrom(backgroundColor: _cyan, foregroundColor: _bg, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Edit Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))),
              ]))),
          ),
          const SizedBox(height: 16),
          _buildSection(title: 'Account', children: [
            _buildMenuItem(Icons.qr_code_2, 'My QR Card', () => context.push('/qr')),
            _buildMenuItem(Icons.history_rounded, 'Ride History', () => context.push('/history')),
            _buildMenuItem(Icons.credit_card_rounded, 'Payment Methods', () => context.push('/payment'), showBorder: false),
          ]),
          const SizedBox(height: 12),
          _buildSection(title: 'Notifications', children: [
            _buildToggle('Bus Arrival Alerts', 'Notify when bus approaches stop', userProvider.busArrivalAlerts, () => userProvider.toggleBusArrivalAlerts()),
            _buildToggle('Service Updates', 'Route changes & disruptions', userProvider.serviceUpdates, () => userProvider.toggleServiceUpdates()),
            _buildToggle('Promotions', 'Special offers & deals', userProvider.promotions, () => userProvider.togglePromotions(), showBorder: false),
          ]),
          const SizedBox(height: 12),
          _buildSection(title: 'Support', children: [
            _buildMenuItem(Icons.help_outline_rounded, 'Help & Support', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()))),
            _buildMenuItem(Icons.shield_outlined, 'Privacy Policy', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()))),
            _buildMenuItem(Icons.description_outlined, 'Terms of Service', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())), showBorder: false),
          ]),
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: double.infinity,
            child: OutlinedButton(
              onPressed: () async { await context.read<AuthProvider>().logout(); if (mounted) GoRouter.of(context).go('/login'); },
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.logout_rounded, size: 16), SizedBox(width: 6),
                Text('Logout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))])))),
          const SizedBox(height: 10),
          const Text('BUSGO v2.4.1 · © 2026 BUSGO Ltd.', style: TextStyle(fontSize: 10, color: Color(0xFF555555))),
          const SizedBox(height: 24),
        ]));
      }),
    );
  }

  Widget _buildStat(String label, String value) => Expanded(child: Column(children: [
    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 10, color: _textSec, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
  ]));

  Widget _statDivider() => Container(width: 1, height: 30, color: _border);

  Widget _buildSection({required String title, required List<Widget> children}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70))),
        ...children,
      ])));

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap, {bool showBorder = true}) => GestureDetector(
    onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(border: showBorder ? Border(bottom: BorderSide(color: _border)) : null),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: _cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: _cyan)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500))),
        Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white.withOpacity(0.2)),
      ])));

  Widget _buildToggle(String title, String subtitle, bool value, VoidCallback onChanged, {bool showBorder = true}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(border: showBorder ? Border(bottom: BorderSide(color: _border)) : null),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70)),
        const SizedBox(height: 1),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: _textSec)),
      ])),
      GestureDetector(onTap: onChanged, child: Container(width: 44, height: 24,
        decoration: BoxDecoration(color: value ? _cyan.withOpacity(0.2) : const Color(0xFF2C3E50), borderRadius: BorderRadius.circular(12)),
        child: AnimatedAlign(duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 20, height: 20, margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: value ? _cyan : const Color(0xFF555555), shape: BoxShape.circle))))),
    ]));
}








