import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/trip_provider.dart';
import '../../services/mock_data_service.dart';
import 'main_shell.dart';
import '../../core/config/api_config.dart';
import '../../providers/route_provider.dart';

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});
  @override State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late AnimationController _pulseController;
  double _currentZoom  = 15.0; // ← closer zoom so driver sees their street
  bool   _followDriver = true; // ← auto-follow toggle

  @override
  void initState() {
    super.initState();
    _mapController  = MapController();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    // ── Start GPS as soon as the map tab opens ─────────────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trip = context.read<TripProvider>();
      if (!trip.gpsReady) trip.initGps();

      // ── Listen to TripProvider — re-center map on every GPS update ────────
      trip.addListener(_onLocationUpdate);
    });
  }

  void _onLocationUpdate() {
    if (!mounted || !_followDriver) return;
    final trip = context.read<TripProvider>();
    // Move map to real GPS position
    _mapController.move(trip.currentLocation, _currentZoom);
  }

  @override
  void dispose() {
    // Remove listener to avoid memory leaks
    context.read<TripProvider>().removeListener(_onLocationUpdate);
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  double _calcDistanceKm(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Kilometer, a, b);

  @override
  Widget build(BuildContext context) =>
      Consumer<TripProvider>(builder: (context, trip, _) {
        final routeProvider = context.read<RouteProvider>();
        final route = trip.currentRoute ?? routeProvider.assignedRoute;

        if (route == null) {
          // Route not loaded yet — trigger load and show spinner
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (routeProvider.assignedRoute == null && !routeProvider.isLoading) {
              routeProvider.loadDriverAssignedRoute();
            }
          });
          return const Scaffold(
            backgroundColor: Color(0xFF040A14),
            body: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.cyan),
                SizedBox(height: 16),
                Text('Loading your route...',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            )),
          );
        }
        final busLocation = trip.currentLocation;
        final nextStop = trip.nextStop ?? (route.stops.isNotEmpty ? route.stops.first : null);
        final traveledPath = trip.traveledPath;

        // Build remaining route polyline ahead of bus
        final remainingPath = <LatLng>[busLocation];
        if (route.polyline.isNotEmpty) {
          double minDist = double.infinity;
          int startIdx = 0;
          for (int i = 0; i < route.polyline.length; i++) {
            final d = _calcDistanceKm(busLocation, route.polyline[i]);
            if (d < minDist) { minDist = d; startIdx = i; }
          }
          for (int i = startIdx; i < route.polyline.length; i++) {
            remainingPath.add(route.polyline[i]);
          }
        }

        final origin = route.stops.isNotEmpty ? route.stops.first : null;
        final distToOrigin   = origin != null ? _calcDistanceKm(busLocation, origin.location) : 0.0;
        final etaToOrigin    = (distToOrigin / 0.5).round();
        final distToNext     = nextStop != null ? _calcDistanceKm(busLocation, nextStop.location) : 0.0;
        final etaToNext      = (distToNext / 0.5).round();

        return Scaffold(body: Stack(children: [

          // ── Map ────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: busLocation,
              initialZoom:   _currentZoom,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _currentZoom = _mapController.camera.zoom;
                }
                // If driver manually drags the map, pause auto-follow
                if (event is MapEventScrollWheelZoom ||
                    event is MapEventMove && event.source == MapEventSource.dragStart) {
                  _followDriver = false;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=${ApiConfig.mapTilerKey}',
                userAgentPackageName: 'com.busgo.drive',
              ),
              // Remaining route ahead — faded blue
              if (remainingPath.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(points: remainingPath, strokeWidth: 5,
                      color: AppColors.primaryLight.withValues(alpha: 0.4)),
                ]),
              // Traveled path — green trail
              if (traveledPath.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(points: traveledPath, strokeWidth: 6,
                      color: const Color(0xFF00C853)),
                ]),
              // Bus stop markers
              if (route.stops.isNotEmpty)
                MarkerLayer(markers: List.generate(route.stops.length, (i) {
                  final stop        = route.stops[i];
                  final isCompleted = i < trip.currentStopIndex;
                  final isCurrent   = i == trip.currentStopIndex;
                  return Marker(
                    point: stop.location, width: 28, height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted ? AppColors.success
                              : isCurrent    ? AppColors.warning
                              : AppColors.primaryLight,
                          width: 3)),
                      child: Center(child: Text('${i + 1}',
                          style: GoogleFonts.inter(fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isCompleted ? AppColors.success
                                  : isCurrent    ? AppColors.warning
                                  : AppColors.primaryLight)))));
                })),
              // Animated bus marker at REAL GPS position
              MarkerLayer(markers: [
                Marker(point: busLocation, width: 48, height: 48,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final pulseScale   = 1.0 + _pulseController.value * 0.6;
                      final pulseOpacity = 0.4 * (1 - _pulseController.value);
                      return Stack(alignment: Alignment.center, children: [
                        Container(
                          width: 48 * pulseScale, height: 48 * pulseScale,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              color: AppColors.primaryLight
                                  .withValues(alpha: pulseOpacity))),
                        Container(width: 38, height: 38,
                          decoration: BoxDecoration(color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3)),
                          child: const Icon(Icons.directions_bus_rounded,
                              size: 18, color: Colors.white)),
                      ]);
                    })),
              ]),
            ],
          ),

          // ── GPS error banner ───────────────────────────────────────────────
          if (trip.gpsError != null)
            Positioned(top: MediaQuery.of(context).padding.top + 60, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.gps_off, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(trip.gpsError!,
                      style: GoogleFonts.inter(fontSize: 12,
                          color: Colors.white, fontWeight: FontWeight.w600))),
                ]),
              )),

          // ── Title bar ─────────────────────────────────────────────────────
          Positioned(top: MediaQuery.of(context).padding.top + 14, left: 0, right: 0,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: trip.gpsReady ? Colors.greenAccent : Colors.orange)),
                const SizedBox(width: 6),
                Text(
                  trip.gpsReady
                      ? 'Route ${route.routeNumber} — Live GPS'
                      : 'Route ${route.routeNumber} — Waiting for GPS...',
                  style: GoogleFonts.inter(fontSize: 13,
                      fontWeight: FontWeight.w700, color: Colors.white)),
              ])))),

          // ── Zoom + re-center controls ──────────────────────────────────────
          Positioned(right: 12, top: MediaQuery.of(context).padding.top + 56,
            child: Column(children: [
              _mapCtrlBtn(Icons.add, () {
                _currentZoom = (_currentZoom + 1).clamp(5.0, 18.0);
                _mapController.move(_mapController.camera.center, _currentZoom);
              }),
              const SizedBox(height: 6),
              _mapCtrlBtn(Icons.remove, () {
                _currentZoom = (_currentZoom - 1).clamp(5.0, 18.0);
                _mapController.move(_mapController.camera.center, _currentZoom);
              }),
              const SizedBox(height: 6),
              // Re-center on driver and resume auto-follow
              _mapCtrlBtn(Icons.my_location, () {
                setState(() => _followDriver = true);
                _mapController.move(busLocation, 15);
              }),
            ])),

          // ── Follow indicator (shows when auto-follow is paused) ───────────
          if (!_followDriver)
            Positioned(top: MediaQuery.of(context).padding.top + 56, left: 12,
              child: GestureDetector(
                onTap: () { setState(() => _followDriver = true); _mapController.move(busLocation, 15); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.warning,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_searching, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('Tap to follow', style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ])))),

          // ── Emergency FAB ──────────────────────────────────────────────────
          Positioned(right: 14, bottom: 190,
            child: GestureDetector(
              onTap: () => context
                  .findAncestorStateOfType<MainShellState>()
                  ?.switchToTab(2),
              child: Container(width: 52, height: 52,
                decoration: BoxDecoration(color: AppColors.danger,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: AppColors.danger.withValues(alpha: 0.5),
                        blurRadius: 16, offset: const Offset(0, 4))]),
                child: const Icon(Icons.emergency_rounded,
                    size: 24, color: Colors.white)))),

          // ── Bottom stop info panel ─────────────────────────────────────────
          Positioned(left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16, offset: const Offset(0, -4))]),
              child: SafeArea(top: false, child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Speed indicator
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.speed_rounded, size: 16,
                          color: AppColors.primaryLight),
                      const SizedBox(width: 6),
                      Text(
                        '${trip.currentSpeed.toStringAsFixed(0)} km/h  •  '
                        '${trip.gpsReady ? "GPS Active" : "Acquiring GPS..."}',
                        style: GoogleFonts.inter(fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryLight)),
                    ])),
                  if (origin != null)
                    _stopInfoRow(
                      icon: Icons.flag_rounded, iconColor: AppColors.primaryLight,
                      name: origin.name, etaMin: etaToOrigin,
                      distKm: distToOrigin, label: 'ORIGIN'),
                  if (nextStop?.id != origin?.id) ...[
                    Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1,
                            color: const Color(0xFFEEEEEE))),
                    _stopInfoRow(
                      icon: Icons.navigation_rounded,
                      iconColor: AppColors.success,
                      name: nextStop?.name ?? '', etaMin: etaToNext,
                      distKm: distToNext, label: 'NEXT STOP'),
                  ],
                ]),
              )),
            )),
        ]));
      });

  Widget _stopInfoRow({
    required IconData icon, required Color iconColor,
    required String name, required int etaMin,
    required double distKm, required String label,
  }) =>
      Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9,
              fontWeight: FontWeight.w700, color: const Color(0xFF9E9E9E),
              letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(name, style: GoogleFonts.inter(fontSize: 14,
              fontWeight: FontWeight.w700, color: AppColors.primary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            Icon(Icons.schedule_rounded, size: 12, color: AppColors.success),
            const SizedBox(width: 3),
            Text('$etaMin min', style: GoogleFonts.inter(fontSize: 12,
                fontWeight: FontWeight.w700, color: AppColors.success)),
          ]),
          const SizedBox(height: 2),
          Text('${distKm.toStringAsFixed(1)} km away',
              style: GoogleFonts.inter(fontSize: 11,
                  color: const Color(0xFF8094A8))),
        ]),
      ]);

  Widget _mapCtrlBtn(IconData icon, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
        child: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8, offset: const Offset(0, 2))]),
          child: Icon(icon, size: 20, color: AppColors.primary)));
}





