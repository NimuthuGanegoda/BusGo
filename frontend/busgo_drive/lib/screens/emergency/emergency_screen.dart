import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/main_shell.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmergencyProvider>().reset();
      _messageController.clear();
    });
  }

  @override
  void dispose() { _messageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F4F8),
    body: Consumer<EmergencyProvider>(builder: (context, emergency, _) {
      if (emergency.isSent) return _buildSentView(emergency);
      return _buildAlertForm(emergency);
    }),
  );

  Widget _buildAlertForm(EmergencyProvider emergency) {
    final trip         = context.watch<TripProvider>();
    final routeNum     = trip.currentRoute?.routeNumber ?? '138';
    final isTypeSelected = emergency.selectedType != null;

    return Column(children: [
      Container(width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF8E0000), Color(0xFFC62828)])),
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            bottom: 20, left: 24, right: 24),
        child: Column(children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2)),
            child: const Icon(Icons.emergency_rounded, size: 28, color: Colors.white)),
          const SizedBox(height: 12),
          Text('EMERGENCY ALERT', style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Text('Route $routeNum  •  ${TimeOfDay.now().format(context)}',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9)))),
        ])),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SELECT INCIDENT TYPE', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7A8D), letterSpacing: 0.8)),
          const SizedBox(height: 10),
          _buildOption(emergency: emergency, typeKey: 'medical',
              icon: Icons.medical_services_rounded,
              iconBg: const Color(0xFFFFEBEE), iconColor: const Color(0xFFC62828),
              title: 'Medical Emergency', subtitle: 'Passenger requires immediate medical help'),
          _buildOption(emergency: emergency, typeKey: 'breakdown',
              icon: Icons.build_circle_rounded,
              iconBg: const Color(0xFFFFF3E0), iconColor: const Color(0xFFE65100),
              title: 'Vehicle Breakdown', subtitle: 'Bus mechanical failure or engine issue'),
          _buildOption(emergency: emergency, typeKey: 'criminal',
              icon: Icons.shield_rounded,
              iconBg: const Color(0xFFEDE7F6), iconColor: const Color(0xFF4A148C),
              title: 'Criminal Activity', subtitle: 'Threat, theft, or crime on board'),
          _buildOption(emergency: emergency, typeKey: 'other',
              icon: Icons.report_rounded,
              iconBg: const Color(0xFFF3E5F5), iconColor: const Color(0xFF7B1FA2),
              title: 'Other', subtitle: 'Describe the situation below'),
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1),
                border: Border.all(color: const Color(0xFFFFD54F), width: 1),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 34, height: 34,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFECB3),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.touch_app_rounded, size: 18, color: Color(0xFFE65100))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hold to confirm', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFE65100))),
                Text('Press and hold for 5 seconds to send alert',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF57F17))),
              ])),
            ])),
          const SizedBox(height: 16),
          _SosHoldButton(
            isLoading:   emergency.isSending,
            isEnabled:   isTypeSelected,
            // ← async callback — button awaits the HTTP call before resetting
            onActivated: () async {
              HapticFeedback.heavyImpact();
              await _sendAlert(emergency);
            },
          ),
        ]),
      )),
    ]);
  }

  Widget _buildSentView(EmergencyProvider emergency) {
    return SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(children: [
        const SizedBox(height: 24),
        Container(width: 100, height: 100,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]),
              shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 52, color: AppColors.success)),
        const SizedBox(height: 24),
        Text('Alert Sent Successfully', style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
        const SizedBox(height: 6),
        Text('Dispatch has been notified. Help is on the way.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7A8D), height: 1.5)),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              emergency.cancelAlert();
              _messageController.clear();
            },
            icon: const Icon(Icons.cancel_outlined, size: 20),
            label: Text('Cancel Alert', style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 52,
          child: OutlinedButton.icon(
            onPressed: () {
              emergency.reset();
              _messageController.clear();
              context.findAncestorStateOfType<MainShellState>()?.switchToTab(0);
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text('Back to Dashboard', style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary,
                side: const BorderSide(color: Color(0xFFD0D7E0), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          )),
      ]),
    ));
  }

  Widget _buildOption({
    required EmergencyProvider emergency,
    required String typeKey,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final isSelected = emergency.selectedType == typeKey;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); emergency.selectType(typeKey); },
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? AppColors.danger : const Color(0xFFE8EDF2),
              width: isSelected ? 2 : 1)),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22, color: iconColor)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8094A8))),
          ])),
          AnimatedContainer(duration: const Duration(milliseconds: 200), width: 24, height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: isSelected ? AppColors.danger : Colors.transparent,
                border: Border.all(
                    color: isSelected ? AppColors.danger : const Color(0xFFD0D7E0), width: 2)),
            child: isSelected
                ? const Center(child: Icon(Icons.check, size: 14, color: Colors.white))
                : null),
        ])),
    );
  }

  Future<void> _sendAlert(EmergencyProvider emergency) async {
    final tp   = context.read<TripProvider>();
    final auth = context.read<AuthProvider>();

    await emergency.sendAlert(
      driverId:  auth.driver?.id ?? 'DRV-UNKNOWN',
      tripId:    tp.currentTrip?.id ?? 'NO-TRIP',
      latitude:  tp.currentLocation.latitude,
      longitude: tp.currentLocation.longitude,
    );

    if (!mounted) return;

    if (emergency.isSent) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: const [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Alert sent — dispatch notified',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ));
    } else if (emergency.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(emergency.error!,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
        ]),
        backgroundColor: const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KEY FIX: onActivated is Future<void> Function() not VoidCallback.
// The status listener awaits it, so the snackbar fires only after the real
// HTTP response — not before it.
// ─────────────────────────────────────────────────────────────────────────────
class _SosHoldButton extends StatefulWidget {
  final bool isLoading;
  final bool isEnabled;
  final Future<void> Function() onActivated;

  const _SosHoldButton({
    required this.isLoading,
    required this.isEnabled,
    required this.onActivated,
  });

  @override State<_SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<_SosHoldButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding    = false;
  bool _isActivating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..addStatusListener((status) async {
        if (status == AnimationStatus.completed && !_isActivating) {
          _isActivating = true;
          _controller.reset();
          if (mounted) setState(() => _isHolding = false);
          await widget.onActivated(); // awaited — snackbar appears after HTTP finishes
          if (mounted) setState(() => _isActivating = false);
        }
      });
  }

  @override void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return Container(
      width: double.infinity, height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppColors.danger.withValues(alpha: 0.8), AppColors.danger]),
        borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 22, width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
        const SizedBox(width: 12),
        Text('SENDING ALERT...', style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: 0.5)),
      ]));

    return GestureDetector(
      onLongPressStart: (widget.isEnabled && !_isActivating)
          ? (_) {
              HapticFeedback.heavyImpact();
              setState(() => _isHolding = true);
              _controller.forward();
            }
          : null,
      onLongPressEnd: (_) {
        if (!_isActivating) {
          _controller.reset();
          setState(() => _isHolding = false);
        }
      },
      child: AnimatedBuilder(animation: _controller, builder: (context, _) {
        final progress = _controller.value;
        return Container(
          width: double.infinity, height: 58,
          decoration: BoxDecoration(
            gradient: widget.isEnabled
                ? const LinearGradient(colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)])
                : null,
            color: widget.isEnabled ? null : const Color(0xFFBDBDBD),
            borderRadius: BorderRadius.circular(16)),
          child: Stack(children: [
            if (_isHolding) FractionallySizedBox(widthFactor: progress,
              child: Container(decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16)))),
            Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                _isHolding ? Icons.hourglass_top_rounded : Icons.emergency_rounded,
                size: 22, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                _isHolding
                    ? 'SENDING IN ${(5 - (progress * 5)).ceil()}s...'
                    : 'HOLD TO SEND ALERT',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 0.8)),
            ])),
          ]));
      }),
    );
  }
}
