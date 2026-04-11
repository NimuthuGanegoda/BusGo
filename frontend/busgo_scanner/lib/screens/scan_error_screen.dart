import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class ScanErrorScreen extends StatelessWidget {
  final String errorMessage;
  const ScanErrorScreen({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    // Map API error codes to user-friendly messages
    final displayMsg = _friendlyMessage(errorMessage);

    return Scaffold(
      backgroundColor: AppColors.scannerBg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: AppColors.scannerSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              Text('Scan Failed', style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),

          Expanded(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

              // Error icon
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2), shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.2),
                    blurRadius: 24, spreadRadius: 4,
                  )],
                ),
                child: const Icon(Icons.error_rounded, size: 60, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 24),

              Text('Scan Failed', style: GoogleFonts.inter(
                fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(displayMsg, textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF991B1B), height: 1.5)),
              ),
              const SizedBox(height: 32),

              // Tip box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text('Common fixes', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                  const SizedBox(height: 8),
                  for (final tip in _tips(errorMessage))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('• ', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        Expanded(child: Text(tip, style: GoogleFonts.inter(fontSize: 13, color: Colors.white54))),
                      ]),
                    ),
                ]),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: Text('Try Again', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white,
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
              ),
            ]),
          )),
        ]),
      ),
    );
  }

  String _friendlyMessage(String raw) {
    if (raw.contains('INVALID_QR_TOKEN'))     return 'QR code not recognised.\nThis code does not match any registered passenger.';
    if (raw.contains('QR_EXPIRED'))           return 'QR code has expired.\nAsk the passenger to open their BUSGO app and refresh the code.';
    if (raw.contains('TRIP_ALREADY_ONGOING')) return 'This passenger is already on a trip.\nThey must exit before boarding again.';
    if (raw.contains('ACCOUNT_INACTIVE'))     return 'Passenger account is inactive.\nPlease ask them to contact support.';
    if (raw.contains('BUS_NOT_RESOLVED'))     return 'Could not determine your bus.\nMake sure your driver account is assigned to an active bus.';
    if (raw.contains('NO_ONGOING_TRIP'))      return 'No active trip found for this passenger.\nThey must board before alighting.';
    if (raw.contains('SocketException') || raw.contains('Connection')) return 'Network error.\nCheck your internet connection and try again.';
    return raw.isNotEmpty ? raw : 'An unexpected error occurred. Please try again.';
  }

  List<String> _tips(String raw) {
    if (raw.contains('QR_EXPIRED')) {
      return ['Ask passenger to open BUSGO app', 'Tap the QR code button to refresh', 'Scan within 30 seconds of refreshing'];
    }
    if (raw.contains('INVALID_QR_TOKEN')) {
      return ['Ensure camera is focused on the QR code', 'The code must be from the BUSGO passenger app', 'Check if the QR is damaged or unclear'];
    }
    if (raw.contains('SocketException')) {
      return ['Check your mobile data or Wi-Fi', 'Move to an area with better signal', 'Retry when connection is restored'];
    }
    return ['Ensure good lighting when scanning', 'Hold the phone steady', 'Ask passenger to increase screen brightness'];
  }
}
