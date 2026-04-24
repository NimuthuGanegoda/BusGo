import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScannerHelpScreen extends StatefulWidget {
  const ScannerHelpScreen({super.key});
  @override
  State<ScannerHelpScreen> createState() => _ScannerHelpScreenState();
}

class _ScannerHelpScreenState extends State<ScannerHelpScreen> {
  static const _bg = Color(0xFF040A14);
  static const _surface = Color(0xFF0A1628);
  static const _card = Color(0xFF1A1E2E);
  static const _cyan = Color(0xFF3FEFEF);
  static const _textGray = Color(0xFFB3B3B3);

  int? _expandedFaq;

  final _faqs = const [
    {
      'q': 'How do I scan a passenger\'s QR code?',
      'a': 'Point your camera at the passenger\'s QR code displayed on their BUSGO app. The scanner will automatically detect and verify the code. Make sure you\'re in the correct mode (Boarding or Alighting).',
    },
    {
      'q': 'What if the scan fails?',
      'a': 'If a scan fails, ask the passenger to refresh their QR code in the BUSGO app. If the problem persists, check your internet connection. The scanner requires an active network connection to verify tickets.',
    },
    {
      'q': 'How do I switch between Boarding and Alighting mode?',
      'a': 'On the scanner screen, tap the mode toggle at the top. Green (Boarding) is for passengers getting on the bus, Red (Alighting) is for passengers getting off.',
    },
    {
      'q': 'What does "QR Expired" mean?',
      'a': 'QR codes refresh periodically for security. If you see this message, ask the passenger to open their BUSGO app and generate a new QR code.',
    },
    {
      'q': 'The camera isn\'t working. What should I do?',
      'a': 'Make sure you\'ve granted camera permissions to the BUSGO Scanner app. Go to your phone\'s Settings → Apps → BUSGO Scanner → Permissions → Camera → Allow.',
    },
    {
      'q': 'How do I report a technical issue?',
      'a': 'Use the contact form below or email support@busgo.lk with a description of the issue, your device model, and any error messages you\'re seeing.',
    },
  ];

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
              Text('Help & Support', style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _cyan.withOpacity(0.08), _surface,
                    ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cyan.withOpacity(0.1)),
                  ),
                  child: Column(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _cyan.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: _cyan.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.headset_mic_rounded, color: _cyan, size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text('How can we help?', style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Find answers or contact our support team',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white38)),
                  ]),
                ),
                const SizedBox(height: 24),

                // Quick actions
                Text('QUICK ACTIONS', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _quickAction(Icons.email_outlined, 'Email\nSupport', 'support@busgo.lk')),
                  const SizedBox(width: 12),
                  Expanded(child: _quickAction(Icons.phone_outlined, 'Call\nHotline', '+94 11 234 5678')),
                  const SizedBox(width: 12),
                  Expanded(child: _quickAction(Icons.bug_report_outlined, 'Report\nBug', 'bugs@busgo.lk')),
                ]),
                const SizedBox(height: 24),

                // FAQ
                Text('FREQUENTLY ASKED QUESTIONS', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                ...List.generate(_faqs.length, (i) => _faqItem(i)),
                const SizedBox(height: 24),

                // Contact form
                Text('SEND US A MESSAGE', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _card, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(children: [
                    _formField('Subject', Icons.subject_rounded),
                    const SizedBox(height: 14),
                    _formField('Your Message', Icons.message_outlined, maxLines: 4),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Message sent! We\'ll get back to you soon.'),
                          backgroundColor: const Color(0xFF2ECC71),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      },
                      child: Container(
                        width: double.infinity, height: 48,
                        decoration: BoxDecoration(
                          color: _cyan, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text('Send Message', style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: _bg)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                Center(child: Text('BUSGO Scanner v2.0.0',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white24))),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: [
        Icon(icon, color: _cyan, size: 24),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(sub, style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
            textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _faqItem(int index) {
    final faq = _faqs[index];
    final expanded = _expandedFaq == index;
    return GestureDetector(
      onTap: () => setState(() => _expandedFaq = expanded ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: expanded ? _cyan.withOpacity(0.06) : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: expanded ? _cyan.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(faq['q']!, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
            Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: _cyan, size: 20),
          ]),
          if (expanded) ...[
            const SizedBox(height: 10),
            Text(faq['a']!, style: GoogleFonts.inter(
                fontSize: 13, color: _textGray, height: 1.5)),
          ],
        ]),
      ),
    );
  }

  Widget _formField(String hint, IconData icon, {int maxLines = 1}) {
    return TextField(
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white24),
        prefixIcon: maxLines == 1 ? Icon(icon, size: 18, color: Colors.white24) : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _cyan.withOpacity(0.4))),
      ),
    );
  }
}
