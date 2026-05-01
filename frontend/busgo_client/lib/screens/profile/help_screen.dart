import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const _bg = Color(0xFF040A14);
  static const _surface = Color(0xFF0A1628);
  static const _card = Color(0xFF1A1E2E);
  static const _cyan = Color(0xFF4ECDC4);
  static const _textGray = Color(0xFFB3B3B3);
  int? _expanded;

  final _faqs = const [
    {'q': 'How do I find nearby buses?', 'a': 'Open the Map tab to see all active buses near you in real-time. You can tap any bus to see its route, ETA, and crowd level.'},
    {'q': 'How do I purchase a ticket?', 'a': 'Go to My QR from the home screen. Your digital QR card is generated automatically. Show it to the scanner operator when boarding.'},
    {'q': 'What does the crowd indicator mean?', 'a': 'Green = plenty of seats, Yellow = filling up, Red = very crowded. This helps you decide which bus to take.'},
    {'q': 'How accurate are the ETAs?', 'a': 'ETAs are calculated using real-time GPS data from buses and traffic conditions. They update every 10 seconds for selected buses.'},
    {'q': 'How do I report an emergency?', 'a': 'Tap the Emergency button on the home screen. Fill in the details and submit. Your alert will be sent to BUSGO operations and nearby authorities.'},
    {'q': 'My QR code was rejected. What do I do?', 'a': 'Try refreshing your QR code in the My QR screen. If the problem persists, check your internet connection or contact support.'},
  ];

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
            Text('Help & Support', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_cyan.withOpacity(0.08), _surface], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(16), border: Border.all(color: _cyan.withOpacity(0.1))),
              child: Column(children: [
                Container(width: 56, height: 56,
                  decoration: BoxDecoration(color: _cyan.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: _cyan.withOpacity(0.3))),
                  child: Icon(Icons.headset_mic_rounded, color: _cyan, size: 28)),
                const SizedBox(height: 14),
                Text('How can we help?', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Text('Find answers or contact support', style: GoogleFonts.inter(fontSize: 13, color: Colors.white38)),
              ]),
            ),
            const SizedBox(height: 24),
            Text('QUICK ACTIONS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _qa(Icons.email_outlined, 'Email\nSupport', 'support@busgo.lk')),
              const SizedBox(width: 12),
              Expanded(child: _qa(Icons.phone_outlined, 'Call\nHotline', '+94 11 234 5678')),
              const SizedBox(width: 12),
              Expanded(child: _qa(Icons.bug_report_outlined, 'Report\nBug', 'bugs@busgo.lk')),
            ]),
            const SizedBox(height: 24),
            Text('FAQ', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            ...List.generate(_faqs.length, (i) {
              final faq = _faqs[i]; final exp = _expanded == i;
              return GestureDetector(
                onTap: () => setState(() => _expanded = exp ? null : i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300), margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: exp ? _cyan.withOpacity(0.06) : _card, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: exp ? _cyan.withOpacity(0.2) : Colors.white.withOpacity(0.05))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(faq['q']!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
                      Icon(exp ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: _cyan, size: 20)]),
                    if (exp) ...[const SizedBox(height: 10), Text(faq['a']!, style: GoogleFonts.inter(fontSize: 13, color: _textGray, height: 1.5))],
                  ]),
                ),
              );
            }),
            const SizedBox(height: 24),
            Text('SEND US A MESSAGE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.05))),
              child: Column(children: [
                _ff('Subject', Icons.subject_rounded),
                const SizedBox(height: 14),
                _ff('Your Message', Icons.message_outlined, lines: 4),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Message sent!'),
                    backgroundColor: const Color(0xFF2ECC71), behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                  child: Container(width: double.infinity, height: 48, decoration: BoxDecoration(color: _cyan, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text('Send Message', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _bg))),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            Center(child: Text('BUSGO v2.4.1', style: GoogleFonts.inter(fontSize: 12, color: Colors.white24))),
            const SizedBox(height: 8),
          ]),
        )),
      ])),
    );
  }

  Widget _qa(IconData icon, String label, String sub) => Container(
    padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.05))),
    child: Column(children: [Icon(icon, color: _cyan, size: 24), const SizedBox(height: 8),
      Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3), textAlign: TextAlign.center),
      const SizedBox(height: 4), Text(sub, style: GoogleFonts.inter(fontSize: 9, color: Colors.white38), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)]),
  );

  Widget _ff(String hint, IconData icon, {int lines = 1}) => TextField(maxLines: lines,
    style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
    decoration: InputDecoration(hintText: hint, hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white24),
      prefixIcon: lines == 1 ? Icon(icon, size: 18, color: Colors.white24) : null,
      filled: true, fillColor: Colors.white.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _cyan.withOpacity(0.4)))));
}







