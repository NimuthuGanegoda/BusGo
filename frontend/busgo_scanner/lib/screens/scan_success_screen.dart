import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/scanner_api_service.dart';

class ScanSuccessScreen extends StatelessWidget {
  final ScanResult result;
  const ScanSuccessScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isPaid     = result.status == 'PAID';
    final color      = isPaid ? const Color(0xFF166534) : const Color(0xFFB45309);
    final bgColor    = isPaid ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB);
    final icon       = isPaid ? Icons.check_circle_rounded : Icons.monetization_on_rounded;
    final label      = isPaid ? 'TICKET VERIFIED' : 'CASH PAYMENT';

    return Scaffold(
      backgroundColor: AppColors.scannerBg,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Container(
            color: AppColors.scannerSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              Text('Scan Result', style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),

          Expanded(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

              // Success icon
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: bgColor, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: color.withOpacity(0.2), blurRadius: 24, spreadRadius: 4,
                  )],
                ),
                child: Icon(icon, size: 60, color: color),
              ),
              const SizedBox(height: 24),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(label, style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: color, letterSpacing: 1.5,
                  )),
                ]),
              ),
              const SizedBox(height: 32),

              // Ticket info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30, backgroundColor: color.withOpacity(0.1),
                    child: Text(result.passengerName.isNotEmpty ? result.passengerName[0].toUpperCase() : 'P',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
                  ),
                  const SizedBox(height: 12),
                  Text(result.passengerName, style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1A1D26))),
                  const SizedBox(height: 4),
                  Text(result.status, style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280), letterSpacing: 1.2,
                  )),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  if (isPaid) ...[
                    _row('From', result.boardingStop),
                    const SizedBox(height: 8),
                    _row('To', result.alightingStop),
                    const SizedBox(height: 8),
                  ],
                  _row('Status', result.message),
                ]),
              ),

              const Spacer(),

              // Scan Next button
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  label: Text('Scan Next Passenger', style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white,
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Done for now', style: GoogleFonts.inter(
                  color: Colors.white54, fontSize: 14)),
              ),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
      Flexible(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A1D26)),
        textAlign: TextAlign.right)),
    ],
  );
}
