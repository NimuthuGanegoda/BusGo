import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _bg = Color(0xFF040A14);
  static const _surface = Color(0xFF0A1628);
  static const _card = Color(0xFF1A1E2E);
  static const _cyan = Color(0xFF4ECDC4);
  static const _textGray = Color(0xFFB3B3B3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: _surface.withOpacity(0.95),
            border: Border(bottom: BorderSide(color: _cyan.withOpacity(0.1)))),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white70))),
            const SizedBox(width: 14),
            Text('Privacy Policy', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_cyan.withOpacity(0.1), _surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16), border: Border.all(color: _cyan.withOpacity(0.15))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.shield_outlined, color: _cyan, size: 28), const SizedBox(width: 12),
                  Text('Privacy Policy', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white))]),
                const SizedBox(height: 8),
                Text('Your data, your rights', style: GoogleFonts.inter(fontSize: 14, color: _cyan.withOpacity(0.7))),
                const SizedBox(height: 4),
                Text('Effective: April 2026', style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
              ]),
            ),
            const SizedBox(height: 20),
            _c('Your Privacy Matters', Icons.lock_outline, 'At BUSGO, we protect the privacy of our passengers. This Privacy Policy explains how we collect, use, and safeguard your information.'),
            _c('Information We Collect', Icons.folder_outlined, null, bullets: [
              ['Account Info', 'Name, email, phone number, and payment details.'],
              ['Trip Data', 'Routes taken, boarding/alighting locations, and timestamps.'],
              ['Location Data', 'GPS coordinates when using live map or nearby bus features.'],
              ['Device Info', 'Device model, OS version, and app version for troubleshooting.'],
              ['Payment Records', 'Transaction history for QR ticket purchases.'],
            ]),
            _c('How We Use Your Data', Icons.analytics_outlined, null, bullets: [
              ['Service Delivery', 'To show nearby buses, calculate ETAs, and process payments.'],
              ['Route Optimization', 'To improve bus schedules and route planning.'],
              ['Security', 'To detect fraud and unauthorized access.'],
              ['Communications', 'To send service updates and trip notifications.'],
            ]),
            _c('Data Sharing', Icons.share_outlined, 'We do not sell your personal data. Information may be shared with:\n\n• Bus operators for trip verification\n• Payment processors for transactions\n• Law enforcement when required by Sri Lankan law'),
            _c('Data Security', Icons.security_outlined, 'We use encrypted transmission (TLS), secure authentication, and regular audits. Access to personal data is restricted to authorized personnel.'),
            _c('Your Rights', Icons.gavel_outlined, 'You have the right to:\n\n• Access your personal data\n• Request corrections\n• Request deletion of your account\n• Receive a portable copy of your data\n\nContact privacy@busgo.lk to exercise these rights.'),
            const SizedBox(height: 16),
            Center(child: Text('© 2025-2026 BUSGO. All rights reserved.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white38))),
            const SizedBox(height: 20),
          ]),
        )),
      ])),
    );
  }

  Widget _c(String title, IconData icon, String? body, {List<List<String>>? bullets}) => Container(
    width: double.infinity, margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.05))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: _cyan, size: 20), const SizedBox(width: 10),
        Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))]),
      const SizedBox(height: 12),
      if (body != null) Text(body, style: GoogleFonts.inter(fontSize: 14, color: _textGray, height: 1.6)),
      if (bullets != null) ...bullets.map((b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(margin: const EdgeInsets.only(top: 7), width: 6, height: 6,
            decoration: BoxDecoration(color: _cyan, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: RichText(text: TextSpan(children: [
            TextSpan(text: '${b[0]}: ', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            TextSpan(text: b[1], style: GoogleFonts.inter(fontSize: 14, color: _textGray, height: 1.5)),
          ]))),
        ]),
      )),
    ]),
  );
}
