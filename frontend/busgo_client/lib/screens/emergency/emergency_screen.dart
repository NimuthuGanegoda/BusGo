import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  static const _bg     = Color(0xFF040A14);
  static const _card   = Color(0xFF0A1628);
  static const _cyan   = Color(0xFF4ECDC4);
  static const _border = Color(0x1AFFFFFF);

  final _detailsController = TextEditingController();
  late AnimationController _holdController;
  bool _isHolding = false;

  // Active trip info — fetched when screen opens
  String? _activeBusId;
  String? _activeTripId;
  String? _activeBusNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmergencyProvider>().resetForm();
      _fetchActiveTripInfo();
    });
    _holdController = AnimationController(
        vsync: this, duration: const Duration(seconds: 5));
    _holdController.addStatusListener((s) {
      if (s == AnimationStatus.completed) _onHoldComplete();
    });
  }

  @override
  void dispose() {
    _holdController.stop();
    _holdController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  // ── Fetch active (ongoing) trip to get bus_id automatically ───────────────
  Future<void> _fetchActiveTripInfo() async {
    try {
      final auth  = context.read<AuthProvider>();
      final token = await auth.getAccessToken();
      if (token == null) return;

      // Filter for ongoing trips only so we never pick up a completed trip
      final res = await http.get(
        Uri.parse('$kBaseUrlDev/trips?page=1&page_size=1&status=ongoing'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body    = jsonDecode(res.body) as Map<String, dynamic>;
        final rawData = body['data'];
        final trips   = rawData is List ? rawData : <dynamic>[];

        if (trips.isNotEmpty) {
          final trip = trips.first as Map<String, dynamic>;

          // bus_id is inside the nested 'buses' object returned by the join,
          // NOT at the top level of the trip row
          final busObj = trip['buses'] as Map<String, dynamic>?;

          setState(() {
            _activeTripId    = trip['id']             as String?;
            _activeBusId     = busObj?['id']          as String?; // ← fixed
            _activeBusNumber = busObj?['bus_number']  as String?; // ← fixed
          });

          debugPrint('[Emergency] Active trip: $_activeTripId '
              'bus: $_activeBusId ($_activeBusNumber)');
        } else {
          debugPrint('[Emergency] No ongoing trip found');
        }
      }
    } catch (e) {
      debugPrint('[Emergency] Could not fetch active trip: $e');
    }
  }

  void _onHoldStart() {
    setState(() => _isHolding = true);
    _holdController.forward(from: 0);
  }

  void _onHoldCancel() {
    setState(() => _isHolding = false);
    _holdController.reset();
  }

  // ── Send alert with bus_id and trip_id from active trip ───────────────────
  void _onHoldComplete() async {
    setState(() => _isHolding = false);
    await context.read<EmergencyProvider>().sendAlert(
      busId:  _activeBusId,
      tripId: _activeTripId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Container(color: _bg),
        Container(color: const Color(0xFF0A1628).withOpacity(0.85)),
        SafeArea(child: Center(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildModalContent()))),
      ]),
    );
  }

  Widget _buildModalContent() {
    return Consumer<EmergencyProvider>(builder: (context, emergency, _) {
      if (emergency.alertSent) return _buildSuccessView(emergency);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(
                    color: AppColors.danger.withOpacity(0.3)))),
            child: const Text('⚠️ Emergency Alert',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger))),
          const SizedBox(height: 12),

          // ── Active bus badge ─────────────────────────────────────────────
          if (_activeBusId != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.directions_bus_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are currently on Bus '
                    '${_activeBusNumber ?? _activeBusId} — '
                    'this will be attached to your alert',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600)),
                ),
              ]))
          else
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border)),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.textMuted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No active trip detected — alert will be sent without bus info',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                ),
              ])),

          const Text(
            'Select the type of emergency and describe the situation:',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: AppColors.textMuted, height: 1.5)),
          const SizedBox(height: 12),

          // ── Emergency type selector ────────────────────────────────────
          ...List.generate(EmergencyProvider.displayTypes.length, (index) {
            final isSelected = emergency.selectedType == index;
            return GestureDetector(
              onTap: () => emergency.setSelectedType(index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.danger.withOpacity(0.1)
                      : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isSelected ? AppColors.danger : _border,
                      width: 1.5)),
                child: Row(children: [
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.danger : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSelected
                              ? AppColors.danger : Colors.white24,
                          width: 2))),
                  const SizedBox(width: 10),
                  Text(EmergencyProvider.displayTypes[index],
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ])));
          }),
          const SizedBox(height: 12),

          // ── Comment field ───────────────────────────────────────────────
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Additional Details',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted))),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Describe the situation to help responders (recommended)',
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.3)))),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1E2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border, width: 1.5)),
            child: TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 300,
              onChanged: (v) => emergency.setDetails(v),
              style: const TextStyle(fontSize: 12, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe what is happening...',
                hintStyle: const TextStyle(
                    fontSize: 12, color: Colors.white24),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(10),
                counterStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10)))),
          const SizedBox(height: 12),

          // ── Hold hint ──────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _holdController,
            builder: (context, child) {
              final seconds =
                  (5 - (_holdController.value * 5)).ceil();
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _isHolding
                      ? AppColors.danger.withOpacity(0.1)
                      : AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Text(_isHolding ? '🔴' : '⏳',
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    _isHolding
                        ? 'Hold for $seconds more second${seconds == 1 ? '' : 's'}...'
                        : 'Hold button for 5 seconds to activate',
                    style: TextStyle(
                        fontSize: 11,
                        color: _isHolding
                            ? AppColors.danger : AppColors.warning,
                        fontWeight: FontWeight.w600)),
                ]));
            }),
          const SizedBox(height: 12),

          _buildHoldButton(emergency),
          const SizedBox(height: 8),

          GestureDetector(
            onTap: () => context.pop(),
            child: const Text('Cancel',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMuted))),
        ]),
      );
    });
  }

  Widget _buildHoldButton(EmergencyProvider emergency) {
    if (emergency.isLoading) {
      return Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 10),
          Text('Sending alert...',
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w600, color: Colors.white)),
        ]));
    }

    return GestureDetector(
      onLongPressStart: (_) => _onHoldStart(),
      onLongPressEnd: (_) {
        if (_holdController.status != AnimationStatus.completed) {
          _onHoldCancel();
        }
      },
      onLongPressCancel: _onHoldCancel,
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, child) {
          final progress = _holdController.value;
          return Container(
            width: double.infinity, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _isHolding
                      ? AppColors.danger
                      : Colors.white.withOpacity(0.15),
                  width: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(children: [
                Container(color: AppColors.danger.withOpacity(0.08)),
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  width: MediaQuery.of(context).size.width * progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.danger.withOpacity(0.8),
                        AppColors.danger,
                      ])))),
                Center(child: Row(
                    mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 28, height: 28,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: progress, strokeWidth: 3,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        color: progress > 0.5
                            ? Colors.white : AppColors.danger),
                      Icon(Icons.warning_amber_rounded, size: 14,
                          color: progress > 0.5
                              ? Colors.white : AppColors.danger),
                    ])),
                  const SizedBox(width: 10),
                  Text(
                    _isHolding ? 'Keep holding...' : 'Hold to Send Alert',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: progress > 0.5
                            ? Colors.white : AppColors.danger)),
                ])),
              ])));
        }));
  }

  Widget _buildSuccessView(EmergencyProvider emergency) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('✅', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('Alert Sent Successfully',
          style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.success)),
      const SizedBox(height: 8),
      Text(
        'Emergency type: ${EmergencyProvider.displayTypes[emergency.selectedType]}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      if (_activeBusNumber != null) ...[
        const SizedBox(height: 4),
        Text('Bus: $_activeBusNumber',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textMuted))],
      if (emergency.details.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text('Details: ${emergency.details}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textMuted))],
      const SizedBox(height: 8),
      const Text('Help is on the way. Stay calm.',
          style: TextStyle(fontSize: 12,
              color: Colors.white, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => context.pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _cyan,
            foregroundColor: _bg,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
          child: const Text('Close',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)))),
    ]));
}



