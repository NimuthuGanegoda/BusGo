import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScannerTermsScreen extends StatelessWidget {
  const ScannerTermsScreen({super.key});

  static const _bg = Color(0xFF040A14);
  static const _surface = Color(0xFF0A1628);
  static const _card = Color(0xFF1A1E2E);
  static const _cyan = Color(0xFF3FEFEF);
  static const _textGray = Color(0xFFB3B3B3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _surface.withOpacity(0.95),
              border: Border(bottom: BorderSide(color: _cyan.withOpacity(0.1))),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 14),
              Text('Terms of Service', style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Text('Terms of Service',
                      style: GoogleFonts.josefinSans(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))),
                  const SizedBox(height: 8),
                  Center(child: Text('Last updated: April 2026',
                      style: GoogleFonts.inter(fontSize: 12, color: _cyan.withOpacity(0.6)))),
                  const SizedBox(height: 24),

                  _section('1. Acceptance of Terms',
                    'By accessing and using the BUSGO Scanner application, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service. If you do not agree to these terms, you must not use the application.'),

                  _section('2. Use of Service',
                    'The BUSGO Scanner is designed exclusively for authorized personnel to scan and verify passenger QR codes on BUSGO-operated buses in Sri Lanka. You agree to:\n\n'
                    '• Use the scanner only for its intended purpose of verifying passenger tickets\n'
                    '• Maintain the confidentiality of your login credentials\n'
                    '• Report any unauthorized use or security breaches immediately\n'
                    '• Not attempt to reverse-engineer, modify, or tamper with the application'),

                  _section('3. Account Responsibilities',
                    'You are responsible for all activities that occur under your account. You must provide accurate and complete information when creating your account and keep your credentials secure. BUSGO reserves the right to suspend or terminate accounts that violate these terms.'),

                  _section('4. Data Collection & Privacy',
                    'The scanner collects data necessary for ticket verification, including scan timestamps, location data, and passenger verification results. All data is processed in accordance with our Privacy Policy and Sri Lankan data protection laws.'),

                  _section('5. Prohibited Activities',
                    'The following activities are strictly prohibited:\n\n'
                    '• Sharing your scanner credentials with unauthorized persons\n'
                    '• Scanning QR codes for purposes other than ticket verification\n'
                    '• Attempting to bypass security measures or access restrictions\n'
                    '• Using the app to collect personal passenger information\n'
                    '• Any form of harassment or discrimination against passengers'),

                  _section('6. Service Availability',
                    'BUSGO strives to maintain continuous service availability but does not guarantee uninterrupted access. The service may be temporarily unavailable due to maintenance, updates, or circumstances beyond our control.'),

                  _section('7. Limitation of Liability',
                    'BUSGO shall not be liable for any indirect, incidental, special, consequential, or exemplary damages arising from your use of the scanner application, including but not limited to damages for loss of data or service interruption.'),

                  _section('8. Termination',
                    'BUSGO reserves the right to terminate or suspend your access to the scanner application at any time, without prior notice, for violations of these Terms of Service or any applicable laws.'),

                  _section('9. Changes to Terms',
                    'BUSGO may update these Terms of Service from time to time. Continued use of the application after changes constitutes acceptance of the updated terms.'),

                  const SizedBox(height: 16),
                  Center(child: Text('© 2025-2026 BUSGO. All rights reserved.',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white38))),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.josefinSans(
            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        Text(body, style: GoogleFonts.inter(
            fontSize: 14, color: _textGray, height: 1.6)),
      ]),
    );
  }
}
