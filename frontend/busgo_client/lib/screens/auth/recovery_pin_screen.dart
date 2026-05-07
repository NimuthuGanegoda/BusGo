import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

class RecoveryPinScreen extends StatefulWidget {
  final String pin;
  const RecoveryPinScreen({super.key, required this.pin});

  @override
  State<RecoveryPinScreen> createState() => _RecoveryPinScreenState();
}

class _RecoveryPinScreenState extends State<RecoveryPinScreen>
    with SingleTickerProviderStateMixin {

  static const _bg    = Color(0xFF040D18);
  static const _panel = Color(0xFF0A1628);
  static const _teal  = Color(0xFF4ECDC4);

  bool _saved    = false;
  bool _copied   = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.pin));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2),
        () { if (mounted) setState(() => _copied = false); });
  }

  void _share() {
    Share.share(
      'My BUSGO Recovery PIN is: ${widget.pin}\n\n'
      'Keep this safe! I will need it to reset my password.',
      subject: 'BUSGO Recovery PIN',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // Icon
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _panel,
                    border: Border.all(
                      color: _teal.withOpacity(
                          0.3 + 0.3 * _pulseCtrl.value),
                      width: 2),
                    boxShadow: [BoxShadow(
                      color: _teal.withOpacity(
                          0.1 + 0.15 * _pulseCtrl.value),
                      blurRadius: 20,
                      spreadRadius: 4)]),
                  child: const Icon(
                    Icons.key_rounded,
                    size: 36,
                    color: _teal)),
              ),

              const SizedBox(height: 20),

              Text('Your Recovery PIN',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),

              const SizedBox(height: 8),

              Text(
                'Save this PIN somewhere safe.\nYou will need it to reset your password.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.45),
                  height: 1.5)),

              const SizedBox(height: 32),

              // PIN display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _teal.withOpacity(0.3), width: 1.5),
                  boxShadow: [BoxShadow(
                    color: _teal.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8))]),
                child: Column(children: [

                  Text('RECOVERY PIN',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _teal.withOpacity(0.6),
                      letterSpacing: 2)),

                  const SizedBox(height: 16),

                  // PIN digits
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.pin.split('').map((digit) =>
                      Container(
                        width: 38, height: 48,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: _teal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _teal.withOpacity(0.25))),
                        alignment: Alignment.center,
                        child: Text(digit,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)))).toList()),

                  const SizedBox(height: 20),

                  // Copy + Share buttons
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _copy,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _copied
                                ? const Color(0xFF16A34A).withOpacity(0.15)
                                : _teal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _copied
                                  ? const Color(0xFF16A34A).withOpacity(0.4)
                                  : _teal.withOpacity(0.25))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _copied
                                    ? Icons.check_rounded
                                    : Icons.copy_rounded,
                                size: 16,
                                color: _copied
                                    ? const Color(0xFF4ADE80)
                                    : _teal),
                              const SizedBox(width: 8),
                              Text(
                                _copied ? 'Copied!' : 'Copy',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _copied
                                      ? const Color(0xFF4ADE80)
                                      : _teal)),
                            ])),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _share,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withOpacity(0.25))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.share_rounded,
                                size: 16,
                                color: Color(0xFF818CF8)),
                              const SizedBox(width: 8),
                              Text('Share',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF818CF8))),
                            ])),
                      ),
                    ),
                  ]),
                ])),

              const SizedBox(height: 24),

              // Warning box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'This PIN will NOT be shown again. '
                    'Store it in a safe place like WhatsApp '
                    'saved messages or your Notes app.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFFF59E0B).withOpacity(0.9),
                      height: 1.5))),
                ])),

              const SizedBox(height: 24),

              // Checkbox
              GestureDetector(
                onTap: () => setState(() => _saved = !_saved),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _saved
                        ? const Color(0xFF16A34A).withOpacity(0.08)
                        : _panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _saved
                          ? const Color(0xFF16A34A).withOpacity(0.4)
                          : Colors.white.withOpacity(0.08))),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: _saved
                            ? const Color(0xFF16A34A)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _saved
                              ? const Color(0xFF16A34A)
                              : Colors.white.withOpacity(0.25),
                          width: 2)),
                      child: _saved
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      'I have safely stored my recovery PIN',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _saved
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withOpacity(0.6)))),
                  ])),
              ),

              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: _saved
                        ? const LinearGradient(
                            colors: [Color(0xFF3BBFB8), Color(0xFF4ECDC4)])
                        : null,
                    color: _saved ? null : Colors.white.withOpacity(0.05),
                    boxShadow: _saved ? [BoxShadow(
                      color: _teal.withOpacity(0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5))] : null),
                  child: ElevatedButton(
                    onPressed: _saved ? () => context.go('/home') : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                    child: Text(
                      _saved ? 'Continue to App' : 'Tick the checkbox to continue',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _saved
                            ? Colors.white
                            : Colors.white.withOpacity(0.25)))))),

              const SizedBox(height: 16),

              Text(
                'Your 3 security questions + this PIN\nare required to reset your password.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.2),
                  height: 1.5)),

            ],
          ),
        ),
      ),
    );
  }
}