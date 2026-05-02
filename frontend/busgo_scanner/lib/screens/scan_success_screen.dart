import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/scanner_api_service.dart';

class ScanSuccessScreen extends StatelessWidget {
  final ScanResult result;
  const ScanSuccessScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    // ── Determine display based on scan type ─────────────────────────────────
    final isExit  = result.isExit;
    final isPaid  = result.status == 'PAID';

    // Colors, icons and labels change based on boarding vs alighting
    final Color  accentColor;
    final Color  bgColor;
    final IconData icon;
    final String badgeLabel;

    if (isExit) {
      // Alighting — teal theme
      accentColor = const Color(0xFF0D7377);
      bgColor     = const Color(0xFFE6F7F8);
      icon        = Icons.logout_rounded;
      badgeLabel  = 'PASSENGER ALIGHTED';
    } else if (isPaid) {
      // Boarding — paid ticket — green theme
      accentColor = const Color(0xFF166534);
      bgColor     = const Color(0xFFF0FDF4);
      icon        = Icons.check_circle_rounded;
      badgeLabel  = 'TICKET VERIFIED';
    } else {
      // Boarding — cash — amber theme
      accentColor = const Color(0xFFB45309);
      bgColor     = const Color(0xFFFFFBEB);
      icon        = Icons.monetization_on_rounded;
      badgeLabel  = 'CASH PAYMENT';
    }

    return Scaffold(
      backgroundColor: AppColors.scannerBg,
      body: SafeArea(
        child: Column(children: [

          // ── Top bar ────────────────────────────────────────────────────────
          Container(
            color: AppColors.scannerSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              Text('Scan Result', style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
            ]),
          ),

          Expanded(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Icon ──────────────────────────────────────────────────────
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: accentColor.withOpacity(0.25),
                      blurRadius: 24,
                      spreadRadius: 4,
                    )],
                  ),
                  child: Icon(icon, size: 60, color: accentColor),
                ),
                const SizedBox(height: 24),

                // ── Status badge ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: accentColor.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 18, color: accentColor),
                    const SizedBox(width: 8),
                    Text(badgeLabel, style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 1.5,
                    )),
                  ]),
                ),
                const SizedBox(height: 32),

                // ── Passenger info card ────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )],
                  ),
                  child: Column(children: [
                    // Avatar
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: accentColor.withOpacity(0.1),
                      child: Text(
                        result.passengerName.isNotEmpty
                            ? result.passengerName[0].toUpperCase()
                            : 'P',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: accentColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(result.passengerName, style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1D26))),
                    const SizedBox(height: 4),

                    // Boarding / Alighting label
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isExit ? '🚪 Alighting' : '🚌 Boarding',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Route details
                    if (result.boardingStop.isNotEmpty) ...[
                      _row('From', result.boardingStop),
                      const SizedBox(height: 8),
                    ],
                    if (result.alightingStop.isNotEmpty) ...[
                      _row('To', result.alightingStop),
                      const SizedBox(height: 8),
                    ],

                    // Verification message
                    _row('Status', result.message),

                    // Extra confirmation for alighting
                    if (isExit) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.check_circle_outline,
                              size: 16, color: accentColor),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Passenger has exited the bus. Trip ended.',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: accentColor,
                                fontWeight: FontWeight.w600),
                          )),
                        ]),
                      ),
                    ],
                  ]),
                ),

                const Spacer(),

                // ── Scan next button ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                    label: Text('Scan Next Passenger',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Done for now',
                      style: GoogleFonts.inter(
                          color: Colors.white54, fontSize: 14)),
                ),
              ],
            ),
          )),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: GoogleFonts.inter(
          fontSize: 13, color: const Color(0xFF6B7280))),
      Flexible(child: Text(value,
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1D26)))),
    ],
  );
}







