import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const _bg = Color(0xFF040A14);
  static const _card = Color(0xFF1A1E2E);
  static const _cyan = Color(0xFF4ECDC4);
  static const _textGray = Color(0xFFB3B3B3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: Column(children: [
        _topBar(context, 'Terms of Service'),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Text('Terms of Service', style: GoogleFonts.josefinSans(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))),
              const SizedBox(height: 8),
              Center(child: Text('Last updated: April 2026', style: GoogleFonts.inter(fontSize: 12, color: _cyan.withOpacity(0.6)))),
              const SizedBox(height: 24),
              _s('1. Acceptance of Terms', 'By accessing and using the BUSGO application, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service. If you do not agree to these terms, you must not use the application.'),
              _s('2. Use of Service', 'BUSGO provides real-time bus tracking, route planning, and digital ticketing services in Sri Lanka. You agree to:\n\n• Use the app only for its intended purpose of public transport\n• Maintain the confidentiality of your login credentials\n• Report any unauthorized use immediately\n• Not attempt to reverse-engineer or tamper with the application'),
              _s('3. Account Responsibilities', 'You are responsible for all activities under your account. You must provide accurate information and keep your credentials secure. BUSGO reserves the right to suspend accounts that violate these terms.'),
              _s('4. Digital Tickets & Payments', 'QR-based tickets purchased through BUSGO are valid only for the specified route and time. Tickets are non-transferable. Refund policies are subject to the terms displayed at the time of purchase.'),
              _s('5. Data Collection & Privacy', 'BUSGO collects data necessary for service operation, including location data and trip history. All data is processed in accordance with our Privacy Policy and Sri Lankan data protection laws.'),
              _s('6. Prohibited Activities', 'The following are strictly prohibited:\n\n• Sharing QR tickets with others\n• Creating multiple accounts\n• Attempting to bypass payment systems\n• Using the app to harass drivers or other passengers\n• Any fraudulent activity'),
              _s('7. Service Availability', 'BUSGO strives for continuous availability but does not guarantee uninterrupted access. Service may be temporarily unavailable due to maintenance or circumstances beyond our control.'),
              _s('8. Limitation of Liability', 'BUSGO shall not be liable for indirect, incidental, or consequential damages arising from your use of the application, including but not limited to missed buses or inaccurate ETAs.'),
              _s('9. Changes to Terms', 'BUSGO may update these Terms from time to time. Continued use constitutes acceptance of updated terms.'),
              const SizedBox(height: 16),
              Center(child: Text('© 2025-2026 BUSGO. All rights reserved.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white38))),
            ]),
          ),
        )),
      ])),
    );
  }

  Widget _s(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.josefinSans(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 8),
      Text(body, style: GoogleFonts.inter(fontSize: 14, color: _textGray, height: 1.6)),
    ]),
  );

  static Widget _topBar(BuildContext context, String title) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFF0A1628).withOpacity(0.95),
      border: Border(bottom: BorderSide(color: const Color(0xFF4ECDC4).withOpacity(0.1)))),
    child: Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context),
        child: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white70))),
      const SizedBox(width: 14),
      Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
    ]),
  );
}



