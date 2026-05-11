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

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isOnline = false;

  late AnimationController _expressAnimCtrl;
  late Animation<double>   _expressPulse;

  @override
  void initState() {
    super.initState();
    _expressAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _expressPulse = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _expressAnimCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final rp   = context.read<RouteProvider>();
      final tp   = context.read<TripProvider>();
      final auth = context.read<AuthProvider>();

      if (rp.routes.isEmpty) {
        await rp.loadRoutes();
      }

      if (auth.driver?.id != null) {
        tp.initPassengerTracking(auth.driver!.id);
      }

      if (tp.currentTrip == null && rp.routes.isNotEmpty) {
        final assignedRoute = rp.assignedRoute ?? rp.routes.first;
        tp.startTrip(assignedRoute);
      }

      await _setBusStatus('inactive');
    });
  }

  @override
  void dispose() {
    _expressAnimCtrl.dispose();
    super.dispose();
  }

  void _goToMapTab() =>
      context.findAncestorStateOfType<MainShellState>()?.switchToTab(1);

  Future<void> _setBusStatus(String status, {double? lat, double? lng}) async {
    try {
      final token = await context.read<AuthProvider>().getToken();
      if (token == null) return;
      await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/driver/status'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[Toggle] Set bus status error: $e');
    }
  }

  Future<void> _toggleOnline(bool value) async {
    final tp = context.read<TripProvider>();
    if (value) {
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
      await _setBusStatus('active',
          lat: tp.currentLocation.latitude,
          lng: tp.currentLocation.longitude);
      tp.startOnlineSession();
      setState(() => _isOnline = true);
    } else {
      final tpOff = context.read<TripProvider>();
      tpOff.stopGpsStream();
      tpOff.stopOnlineSession();
      await _setBusStatus('inactive');
      setState(() => _isOnline = false);
    }
  }

  BoxDecoration _glassDeco({
    Color? color, Color? borderColor, double radius = 14,
    List<BoxShadow>? shadows,
  }) => BoxDecoration(
    color: color ?? AppColors.cardBg,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? AppColors.border),
    boxShadow: shadows ?? [
      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15,
          offset: const Offset(0, 4)),
    ],
  );

  @override
  Widget build(BuildContext context) =>
      Consumer<TripProvider>(builder: (context, trip, _) {
        final passengers  = trip.currentPassengers;
        final totalSeats  = trip.busCapacity;
        final fillPercent = (passengers / totalSeats).clamp(0.0, 1.0);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(children: [
            _buildTopBar(trip),
            if (trip.isExpressMode) _buildExpressBanner(trip),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(children: [

                  // Online / Offline toggle
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: _glassDeco(
                      borderColor: _isOnline
                          ? AppColors.success.withOpacity(0.3) : AppColors.border),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isOnline
                                ? AppColors.success.withOpacity(0.15)
                                : Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.circle, size: 18,
                              color: _isOnline ? AppColors.success : Colors.grey)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline ? 'You are Online' : 'You are Offline',
                              style: GoogleFonts.inter(fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                            Text(
                              _isOnline
                                  ? 'GPS active \u2014 passengers can see your bus'
                                  : 'Toggle ON to share your location',
                              style: GoogleFonts.inter(fontSize: 11,
                                  color: AppColors.textSecondary)),
                          ])),
                        GestureDetector(
                          onTap: () => _toggleOnline(!_isOnline),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 60, height: 30,
                            decoration: BoxDecoration(
                              color: _isOnline
                                  ? AppColors.success.withOpacity(0.2)
                                  : const Color(0xFF2C3E50),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 10)]),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 300),
                              alignment: _isOnline
                                  ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.all(3),
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: _isOnline
                                      ? AppColors.success : const Color(0xFF3498DB),
                                  shape: BoxShape.circle))),
                          )),
                      ]),
                    ),
                  ),

                  // GPS status
                  if (_isOnline && trip.gpsReady)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: _glassDeco(
                        color: AppColors.success.withOpacity(0.08),
                        borderColor: AppColors.success.withOpacity(0.3), radius: 12),
                      child: Row(children: [
                        const Icon(Icons.gps_fixed, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'GPS Active \u2014 '
                          '${trip.currentLocation.latitude.toStringAsFixed(5)}, '
                          '${trip.currentLocation.longitude.toStringAsFixed(5)}'
                          '  \u2022  ${trip.currentSpeed.toStringAsFixed(0)} km/h',
                          style: GoogleFonts.inter(fontSize: 11,
                              color: AppColors.success, fontWeight: FontWeight.w600))),
                      ])),

                  if (_isOnline && !trip.gpsReady)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: _glassDeco(
                        color: AppColors.warning.withOpacity(0.08),
                        borderColor: AppColors.warning.withOpacity(0.3), radius: 12),
                      child: Row(children: [
                        const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.warning)),
                        const SizedBox(width: 8),
                        Text('Acquiring GPS...', style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.warning)),
                      ])),

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

  Widget _buildExpressBanner(TripProvider trip) {
    return AnimatedBuilder(
      animation: _expressPulse,
      builder: (_, __) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFDC2626).withOpacity(_expressPulse.value),
              const Color(0xFF7F1D1D).withOpacity(_expressPulse.value),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFEF4444).withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text('EXPRESS MODE',
                    style: GoogleFonts.inter(fontSize: 11,
                        fontWeight: FontWeight.w900, color: Colors.white,
                        letterSpacing: 1.2)),
              ])),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${trip.currentPassengers}/${trip.busCapacity} seats',
                style: GoogleFonts.inter(fontSize: 11,
                    fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Bus is at full capacity. Skipping stops with no passengers.',
            style: GoogleFonts.inter(fontSize: 12,
                color: Colors.white.withOpacity(0.9), height: 1.4)),
          if (trip.mustStopCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.location_on_rounded, size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    'Must stop at ${trip.mustStopCount} '
                    '${trip.mustStopCount == 1 ? 'stop' : 'stops'}:',
                    style: GoogleFonts.inter(fontSize: 11,
                        fontWeight: FontWeight.w600, color: Colors.white70)),
                ]),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: trip.mustStopAt.map((stop) {
                    final name = stop['name'] as String? ?? 'Stop';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12)),
                      child: Text(name, style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: Colors.white)),
                    );
                  }).toList(),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Express mode disables automatically when passengers alight.',
            style: GoogleFonts.inter(fontSize: 10,
                color: Colors.white.withOpacity(0.6),
                fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }

  Widget _buildTopBar(TripProvider trip) {
    final routeNumber = trip.currentRoute?.routeNumber ?? '138';
    final routeName   = trip.currentRoute?.routeDirection ?? 'Kaduwela \u2192 Colombo Fort';
    final now         = TimeOfDay.now();
    final timeStr     = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)))),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20, right: 20, bottom: 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('On Duty \u2014 Route $routeNumber',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 3),
          Text(routeName, style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.accent)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isOnline
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.danger.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isOnline
                    ? AppColors.success.withOpacity(0.5)
                    : AppColors.danger.withOpacity(0.5))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                      color: _isOnline ? AppColors.success : AppColors.danger,
                      shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(_isOnline ? 'ONLINE' : 'OFFLINE',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                      color: _isOnline ? AppColors.success : AppColors.danger,
                      letterSpacing: 0.5)),
            ])),
          const SizedBox(height: 4),
          Text(timeStr, style: GoogleFonts.inter(fontSize: 13,
              fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ]),
    );
  }

  Widget _buildPassengerGauge(int passengers, int totalSeats, double fillPercent) {
    Color gaugeColor;
    if (fillPercent < 0.5)       gaugeColor = AppColors.success;
    else if (fillPercent < 0.75) gaugeColor = AppColors.warning;
    else if (fillPercent < 1.0)  gaugeColor = AppColors.danger;
    else                         gaugeColor = Colors.white;

    return Container(
      decoration: _glassDeco(
        color: const Color(0xCC1E1E1E),
        borderColor: AppColors.accent.withOpacity(0.15), radius: 18),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        SizedBox(
          width: 170, height: 170,
          child: CustomPaint(
            painter: _GaugeRingPainter(
              fillPercent: fillPercent,
              fillColor:   gaugeColor,
              bgColor:     Colors.white.withOpacity(0.1)),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$passengers',
                  style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800,
                      color: AppColors.accent, height: 1)),
              const SizedBox(height: 2),
              Text('/ $totalSeats seats',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              Text('on board',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
            ]))),
        ),
      ]),
    );
  }

  Widget _buildMapPreview(TripProvider trip) {
    final routeProvider = context.read<RouteProvider>();
    final route       = trip.currentRoute ?? routeProvider.assignedRoute ?? MockDataService.routes.first;
    final busLocation = trip.currentLocation;
    final traveledPath= trip.traveledPath;

    return GestureDetector(
      onTap: _goToMapTab,
      child: Container(
        decoration: _glassDeco(radius: 14),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            color: const Color(0xB3000000),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Icon(Icons.map_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('Live Route Map', style: GoogleFonts.inter(fontSize: 12,
                    fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
              Text('Tap to expand', style: GoogleFonts.inter(fontSize: 10,
                  color: AppColors.textSecondary)),
            ])),
          SizedBox(height: 150, child: FlutterMap(
            options: MapOptions(
              initialCenter: busLocation,
              initialZoom:   13,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none)),
            children: [
              TileLayer(
                urlTemplate: 'https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=${ApiConfig.mapTilerKey}',
                userAgentPackageName: 'com.busgo.drive'),
              if (route.polyline.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: route.polyline, strokeWidth: 4,
                      color: AppColors.accent.withOpacity(0.35))]),
              if (traveledPath.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(points: traveledPath, strokeWidth: 5,
                      color: AppColors.success)]),
              MarkerLayer(markers: [
                Marker(
                  point: busLocation, width: 30, height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(
                          color: AppColors.accent.withOpacity(0.5),
                          blurRadius: 10, spreadRadius: 2)]),
                    child: const Icon(Icons.directions_bus_rounded,
                        size: 14, color: Colors.white))),
              ]),
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
      decoration: _glassDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              Icon(Icons.navigation_rounded, size: 13, color: AppColors.accent),
              const SizedBox(width: 4),
              Text('NEXT STOP', style: GoogleFonts.inter(fontSize: 11,
                  fontWeight: FontWeight.w700, color: AppColors.accent,
                  letterSpacing: 0.8)),
            ])),
          const Spacer(),
          Text('$stopsCompleted / $totalStops stops',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(nextStop?.name ?? 'Trip Complete',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary))),
          Text('$etaMin min', style: GoogleFonts.inter(fontSize: 12,
              fontWeight: FontWeight.w600, color: AppColors.accent)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: totalStops > 0 ? stopsCompleted / totalStops : 0,
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent))),
      ]),
    );
  }

  Widget _buildTripStats(TripProvider trip) {
    final speed       = trip.currentSpeed;
    final distance    = trip.onlineDistance;
    final durationMin = trip.onlineDurationMinutes;
    final boarded     = trip.totalBoarded;

    return Row(children: [
      Expanded(child: _statTile(icon: Icons.speed_rounded,
          value: speed.toStringAsFixed(0), unit: 'km/h',
          label: 'Speed', color: AppColors.accent)),
      const SizedBox(width: 10),
      Expanded(child: _statTile(icon: Icons.route_rounded,
          value: distance.toStringAsFixed(1), unit: 'km',
          label: 'Distance', color: AppColors.success)),
      const SizedBox(width: 10),
      Expanded(child: _statTile(icon: Icons.timer_outlined,
          value: '$durationMin', unit: 'min',
          label: 'Duration', color: AppColors.warning)),
      const SizedBox(width: 10),
      Expanded(child: _statTile(icon: Icons.people_alt_rounded,
          value: '$boarded', unit: '',
          label: 'Boarded', color: const Color(0xFFAA66CC))),
    ]);
  }

  Widget _statTile({
    required IconData icon, required String value, required String unit,
    required String label, required Color color,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
    decoration: _glassDeco(radius: 12),
    child: Column(children: [
      Container(width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: color)),
      const SizedBox(height: 6),
      RichText(text: TextSpan(children: [
        TextSpan(text: value, style: GoogleFonts.inter(fontSize: 15,
            fontWeight: FontWeight.w800, color: color)),
        if (unit.isNotEmpty)
          TextSpan(text: ' $unit', style: GoogleFonts.inter(fontSize: 9,
              fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ])),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(fontSize: 10,
          fontWeight: FontWeight.w600, color: AppColors.textMuted)),
    ]),
  );
}

class _GaugeRingPainter extends CustomPainter {
  final double fillPercent;
  final Color  fillColor;
  final Color  bgColor;
  _GaugeRingPainter({required this.fillPercent, required this.fillColor,
      required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const sw     = 14.0;
    canvas.drawCircle(center, radius,
        Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = sw);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -pi / 2, 2 * pi * fillPercent, false,
        Paint()..color = fillColor..style = PaintingStyle.stroke
            ..strokeWidth = sw..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _GaugeRingPainter old) =>
      old.fillPercent != fillPercent || old.fillColor != fillColor;
}
