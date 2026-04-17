import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/api_config.dart';
import '../../providers/trip_provider.dart';
import '../../providers/route_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/mock_data_service.dart';
import 'main_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final rp   = context.read<RouteProvider>();
      final tp   = context.read<TripProvider>();
      final auth = context.read<AuthProvider>();

      if (rp.routes.isEmpty) rp.loadRoutes();

      if (auth.driver?.id != null) {
        tp.initPassengerTracking(auth.driver!.id);
      }

      if (tp.currentTrip == null && rp.routes.isNotEmpty) {
        final route138 = rp.routes
            .where((r) => r.routeNumber == '138')
            .firstOrNull;
        if (route138 != null) tp.startTrip(route138);
      }

      // Always reset bus to inactive on app start
      await _setBusStatus('inactive');
      debugPrint('[Init] Bus reset to inactive on login');
    });
  }

  void _goToMapTab() =>
      context.findAncestorStateOfType<MainShellState>()?.switchToTab(1);

  // ── Update bus status via backend API (bypasses RLS) ─────────────────────
  Future<void> _setBusStatus(String status, {double? lat, double? lng}) async {
    try {
      final token = await context.read<AuthProvider>().getToken();
      if (token == null) {
        debugPrint('[Toggle] No token found');
        return;
      }

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/driver/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[Toggle] Status API: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('[Toggle] Set bus status error: $e');
    }
  }

  // ── Toggle online/offline ─────────────────────────────────────────────────
  Future<void> _toggleOnline(bool value) async {
    final tp = context.read<TripProvider>();

    if (value) {
      // Start GPS FIRST to get coordinates
      final granted = await tp.initGps();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('GPS permission required to go online'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }
      // Set active via backend
      await _setBusStatus('active',
          lat: tp.currentLocation.latitude,
          lng: tp.currentLocation.longitude);
      setState(() => _isOnline = true);
    } else {
      // Stop GPS stream first
      context.read<TripProvider>().stopGpsStream();
      // Set inactive via backend
      await _setBusStatus('inactive');
      setState(() => _isOnline = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Consumer<TripProvider>(builder: (context, trip, _) {
        final passengers  = trip.currentPassengers;
        const totalSeats  = 50;
        final fillPercent = (passengers / totalSeats).clamp(0.0, 1.0);

        return Scaffold(
          backgroundColor: const Color(0xFFEDF1F7),
          body: Column(children: [
            _buildTopBar(trip),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(children: [

                  // ── Online / Offline toggle ───────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isOnline
                            ? AppColors.success.withOpacity(0.4)
                            : const Color(0xFFE0E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isOnline
                                ? AppColors.success.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.circle,
                              size: 18,
                              color: _isOnline
                                  ? AppColors.success
                                  : Colors.grey)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline
                                  ? 'You are Online'
                                  : 'You are Offline',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                            Text(
                              _isOnline
                                  ? 'GPS active — passengers can see your bus'
                                  : 'Toggle ON to share your location',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF8094A8))),
                          ])),
                        Switch(
                          value: _isOnline,
                          onChanged: _toggleOnline,
                          activeColor: AppColors.success,
                        ),
                      ]),
                    ),
                  ),

                  // ── GPS status card ───────────────────────────────────
                  if (_isOnline && trip.gpsReady)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.3))),
                      child: Row(children: [
                        const Icon(Icons.gps_fixed,
                            color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'GPS Active — '
                          '${trip.currentLocation.latitude.toStringAsFixed(5)}, '
                          '${trip.currentLocation.longitude.toStringAsFixed(5)}'
                          '  •  ${trip.currentSpeed.toStringAsFixed(0)} km/h',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600))),
                      ]),
                    ),

                  if (_isOnline && !trip.gpsReady)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.3))),
                      child: Row(children: [
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.orange)),
                        const SizedBox(width: 8),
                        Text('Acquiring GPS...',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.orange)),
                      ]),
                    ),

                  _buildPassengerGauge(passengers, totalSeats, fillPercent),
                  const SizedBox(height: 14),
                  _buildMapPreview(trip),
                  const SizedBox(height: 14),
                  _buildNextStopCard(trip),
                  const SizedBox(height: 14),
                  _buildTripStats(trip),
                ]),
              ),
            ),
          ]),
        );
      });

  Widget _buildTopBar(TripProvider trip) {
    final routeNumber = trip.currentRoute?.routeNumber ?? '138';
    final routeName   = trip.currentRoute?.routeDirection
        ?? 'Kaduwela → Colombo Fort';
    final now     = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2342), Color(0xFF123564)]),
      ),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20, right: 20, bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('On Duty — Route $routeNumber',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 3),
              Text(routeName,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF90CAF9))),
            ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isOnline ? AppColors.success : Colors.grey,
                borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(_isOnline ? 'ONLINE' : 'OFFLINE',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5)),
              ])),
            const SizedBox(height: 4),
            Text(timeStr,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ]),
    );
  }

  Widget _buildPassengerGauge(
      int passengers, int totalSeats, double fillPercent) {
    Color gaugeColor;
    if (fillPercent < 0.5)       gaugeColor = AppColors.success;
    else if (fillPercent < 0.75) gaugeColor = AppColors.warning;
    else if (fillPercent < 0.95) gaugeColor = AppColors.danger;
    else                         gaugeColor = const Color(0xFF212121);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1A2E),
            Color(0xFF132F54),
            Color(0xFF1E5AA8),
          ]),
        borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        SizedBox(
          width: 170, height: 170,
          child: CustomPaint(
            painter: _GaugeRingPainter(
              fillPercent: fillPercent,
              fillColor:   gaugeColor,
              bgColor:     Colors.white.withValues(alpha: 0.15)),
            child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$passengers',
                    style: GoogleFonts.inter(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1)),
                const SizedBox(height: 2),
                Text('/ $totalSeats seats',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF90CAF9))),
                Text('on board',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF64B5F6))),
              ])),
          )),
      ]),
    );
  }

  Widget _buildMapPreview(TripProvider trip) {
    final route        = trip.currentRoute ?? MockDataService.routes.first;
    final busLocation  = trip.currentLocation;
    final traveledPath = trip.traveledPath;

    return GestureDetector(
      onTap: _goToMapTab,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E8F0))),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2342), Color(0xFF123564)])),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.map_rounded,
                      size: 16, color: Color(0xFF64B5F6)),
                  const SizedBox(width: 6),
                  Text('Live Route Map',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ]),
                Text('Tap to expand',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF90CAF9))),
              ])),
          SizedBox(height: 150, child: FlutterMap(
            options: MapOptions(
              initialCenter: busLocation,
              initialZoom:   13,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none)),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png'
                    '?key=fsVEp87wcHaGchb3gygh',
                userAgentPackageName: 'com.busgo.drive'),
              if (route.polyline.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                    points:      route.polyline,
                    strokeWidth: 4,
                    color: AppColors.primaryLight
                        .withValues(alpha: 0.35))]),
              if (traveledPath.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points:      traveledPath,
                    strokeWidth: 5,
                    color:       const Color(0xFF00C853))]),
              MarkerLayer(markers: [
                Marker(
                  point:  busLocation,
                  width:  30,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white, width: 2.5)),
                    child: const Icon(
                        Icons.directions_bus_rounded,
                        size: 14, color: Colors.white)))]),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildNextStopCard(TripProvider trip) {
    final nextStop       = trip.nextStop;
    final etaMin         = trip.etaMinutes;
    final stopsCompleted = trip.currentStopIndex;
    final totalStops     = trip.currentRoute?.stops.length ?? 7;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E8F0))),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              Icon(Icons.navigation_rounded,
                  size: 13, color: AppColors.success),
              const SizedBox(width: 4),
              Text('NEXT STOP',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                      letterSpacing: 0.8)),
            ])),
          const Spacer(),
          Text('$stopsCompleted / $totalStops stops',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(
            nextStop?.name ?? 'Trip Complete',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary))),
          Text('$etaMin min',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: totalStops > 0
                ? stopsCompleted / totalStops
                : 0,
            minHeight:       5,
            backgroundColor: const Color(0xFFE4EAF0),
            valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryLight))),
      ]),
    );
  }

  Widget _buildTripStats(TripProvider trip) {
    final speed       = trip.currentSpeed;
    final distance    = trip.currentTrip?.distanceCovered ?? 0.0;
    final startTime   = trip.currentTrip?.startTime;
    final durationMin = startTime != null
        ? DateTime.now().difference(startTime).inMinutes
        : 0;
    final boarded = trip.currentTrip?.passengersBoarded ?? 0;

    return Row(children: [
      Expanded(child: _statTile(
          icon:  Icons.speed_rounded,
          value: speed.toStringAsFixed(0),
          unit:  'km/h',
          label: 'Speed',
          color: AppColors.primaryLight)),
      const SizedBox(width: 10),
      Expanded(child: _statTile(
          icon:  Icons.route_rounded,
          value: distance.toStringAsFixed(1),
          unit:  'km',
          label: 'Distance',
          color: AppColors.success)),
      const SizedBox(width: 10),
      Expanded(child: _statTile(
          icon:  Icons.timer_outlined,
          value: '$durationMin',
          unit:  'min',
          label: 'Duration',
          color: AppColors.warning)),
      const SizedBox(width: 10),
      Expanded(child: _statTile(
          icon:  Icons.people_alt_rounded,
          value: '$boarded',
          unit:  '',
          label: 'Boarded',
          color: const Color(0xFF7B1FA2))),
    ]);
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E8F0))),
        child: Column(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color)),
          const SizedBox(height: 6),
          RichText(text: TextSpan(children: [
            TextSpan(text: value,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
            if (unit.isNotEmpty)
              TextSpan(text: ' $unit',
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8094A8))),
          ])),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7A8D))),
        ]),
      );
}

class _GaugeRingPainter extends CustomPainter {
  final double fillPercent;
  final Color  fillColor;
  final Color  bgColor;

  _GaugeRingPainter({
    required this.fillPercent,
    required this.fillColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center      = Offset(size.width / 2, size.height / 2);
    final radius      = size.width / 2 - 10;
    const strokeWidth = 14.0;
    canvas.drawCircle(center, radius,
        Paint()
          ..color       = bgColor
          ..style       = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * fillPercent,
        false,
        Paint()
          ..color       = fillColor
          ..style       = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap   = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _GaugeRingPainter old) =>
      old.fillPercent != fillPercent || old.fillColor != fillColor;
}