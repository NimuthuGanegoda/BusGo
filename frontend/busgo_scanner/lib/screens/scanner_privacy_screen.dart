import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScannerPrivacyScreen extends StatelessWidget {
  const ScannerPrivacyScreen({super.key});

  static const _bg = Color(0xFF040A14);
  static const _surface = Color(0xFF0A1628);
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
              Text('Privacy Policy', style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _cyan.withOpacity(0.1),
                      _surface,
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cyan.withOpacity(0.15)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.shield_outlined, color: _cyan, size: 28),
                      const SizedBox(width: 12),
                      Text('Privacy Policy', style: GoogleFonts.inter(
                          fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
                    const SizedBox(height: 8),
                    Text('Updates to BUSGO\'s Privacy Policy',
                        style: GoogleFonts.inter(fontSize: 14, color: _cyan.withOpacity(0.7))),
                    const SizedBox(height: 4),
                    Text('Effective: April 2026',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
                  ]),
                ),
                const SizedBox(height: 20),

                _card('Your Privacy Matters', Icons.lock_outline,
                  'At BUSGO, we are committed to protecting the privacy and security of our users, drivers, and scanner operators. This Privacy Policy explains how we collect, use, and safeguard your information when you use the BUSGO Scanner application.'),

                _card('Information We Collect', Icons.folder_outlined, null, children: [
                  _bullet('Account Information', 'Name, email address, and role assigned by BUSGO administration.'),
                  _bullet('Scan Data', 'QR code verification results, timestamps, and boarding/alighting records.'),
                  _bullet('Location Data', 'GPS coordinates during active scanning sessions to associate scans with bus routes.'),
                  _bullet('Device Information', 'Device model, operating system, and app version for troubleshooting.'),
                  _bullet('Usage Logs', 'Login times, session duration, and scan counts for operational monitoring.'),
                ]),

                _card('How We Use Your Data', Icons.analytics_outlined, null, children: [
                  _bullet('Service Operation', 'To verify passenger tickets and maintain accurate boarding records.'),
                  _bullet('Route Optimization', 'To analyze passenger flow and improve route planning.'),
                  _bullet('Security', 'To detect unauthorized access and prevent fraud.'),
                  _bullet('Support', 'To assist you with technical issues and account inquiries.'),
                ]),

                _card('Data Sharing', Icons.share_outlined,
                  'We do not sell your personal data. Information may be shared with:\n\n'
                  '• BUSGO administrative staff for operational purposes\n'
                  '• Law enforcement when required by Sri Lankan law\n'
                  '• Service providers who assist in operating our platform (under strict confidentiality agreements)'),

                _card('Data Security', Icons.security_outlined,
                  'We implement industry-standard security measures including encrypted data transmission (TLS), secure token-based authentication, and regular security audits. Access to personal data is restricted to authorized personnel only.'),

                _card('Data Retention', Icons.schedule_outlined,
                  'Scan records are retained for 12 months for operational and auditing purposes. Account information is retained for the duration of your employment with BUSGO. Upon account termination, personal data is deleted within 30 days.'),

                _card('Your Rights', Icons.gavel_outlined,
                  'You have the right to:\n\n'
                  '• Access your personal data held by BUSGO\n'
                  '• Request correction of inaccurate information\n'
                  '• Request deletion of your account and associated data\n'
                  '• Receive a copy of your data in a portable format\n\n'
                  'To exercise these rights, contact the BUSGO administration.'),

                _card('Contact Us', Icons.email_outlined,
                  'For privacy-related inquiries:\n\n'
                  'Email: privacy@busgo.lk\n'
                  'Address: BUSGO Technologies, Colombo, Sri Lanka'),

                const SizedBox(height: 16),
                Center(child: Text('© 2025-2026 BUSGO. All rights reserved.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white38))),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card(String title, IconData icon, String? body, {List<Widget>? children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: _cyan, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
        ]),
        const SizedBox(height: 12),
        if (body != null)
          Text(body, style: GoogleFonts.inter(fontSize: 14, color: _textGray, height: 1.6)),
        if (children != null) ...children,
      ]),
    );
  }

  Widget _bullet(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 6, height: 6,
          decoration: BoxDecoration(color: _cyan, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: RichText(text: TextSpan(children: [
          TextSpan(text: '$title: ', style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          TextSpan(text: desc, style: GoogleFonts.inter(
              fontSize: 14, color: _textGray, height: 1.5)),
        ]))),
      ]),
    );
  }
}








