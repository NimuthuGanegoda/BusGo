import 'dart:async';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/bus_model.dart';
import '../../providers/bus_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/crowd_indicator.dart';
import '../../core/utils/helpers.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});
  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  // Default fallback — only used if ALL GPS attempts fail
  LatLng _userLocation = const LatLng(6.9271, 79.8612);
  late AnimationController _pulseController;
  Timer? _pollTimer;
  bool _mapReady = false;
  bool _gotGps = false; // track whether we got a real GPS fix

  String get _tileUrl =>
      'https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png'
      '?key=${dotenv.env['MAPTILER_KEY'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getUserLocation();
      await _loadBuses();
      context.read<BusProvider>().subscribeToLiveLocations();
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _loadBuses(silent: true);
      });
    });
  }

  Future<void> _getUserLocation() async {
    try {
      // ── 1. Check & request permission ──────────────────────
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[GPS] Permission denied — using default location');
        return;
      }

      // ── 2. Fast path: last known position (instant, cached) ─
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        debugPrint('[GPS] Got last known: ${lastKnown.latitude}, ${lastKnown.longitude}');
        setState(() {
          _userLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
          _gotGps = true;
        });
        _moveMapToUser();
      }

      // ── 3. Accurate path: current position (may take time) ──
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 15));

        if (!mounted) return;
        debugPrint('[GPS] Got current position: ${position.latitude}, ${position.longitude}');
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _gotGps = true;
        });
        _moveMapToUser();
      } catch (e) {
        debugPrint('[GPS] getCurrentPosition failed: $e');
        // If we already got lastKnown above, that's fine — we'll use it.
        // If not, try one more time with lower accuracy.
        if (!_gotGps) {
          try {
            final fallback = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
            ).timeout(const Duration(seconds: 10));

            if (!mounted) return;
            debugPrint('[GPS] Got fallback position: ${fallback.latitude}, ${fallback.longitude}');
            setState(() {
              _userLocation = LatLng(fallback.latitude, fallback.longitude);
              _gotGps = true;
            });
            _moveMapToUser();
          } catch (e2) {
            debugPrint('[GPS] All attempts failed: $e2');
          }
        }
      }
    } catch (e) {
      debugPrint('[GPS] Location error: $e');
    }
  }

  /// Move map to user location — safe to call whether map is ready or not
  void _moveMapToUser() {
    if (_mapReady && mounted) {
      _mapController.move(_userLocation, 14.0);
    }
    // If map isn't ready yet, onMapReady callback will handle it
  }

  Future<void> _loadBuses({bool silent = false}) async {
    if (!mounted) return;
    await context.read<BusProvider>().loadNearbyBuses(
        _userLocation.latitude, _userLocation.longitude);
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * asin(sqrt(a.clamp(0, 1)));
    return R * c;
  }

  Future<String?> _getDestinationStopId(String? routeId) async {
    try {
      final result = await Supabase.instance.client
          .from('bus_stops')
          .select('id, stop_name, latitude, longitude')
          .limit(400);

      final stops = result as List;
      if (stops.isEmpty) return null;

      String? nearestId;
      double minDist = double.infinity;

      for (final stop in stops) {
        final lat = (stop['latitude']  as num?)?.toDouble();
        final lng = (stop['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final dist = _haversine(
          _userLocation.latitude,
          _userLocation.longitude,
          lat, lng,
        );

        if (dist < minDist) {
          minDist = dist;
          nearestId = stop['id'] as String?;
        }
      }
      return nearestId;
    } catch (e) {
      debugPrint('[ETA] Stop lookup error: $e');
      return null;
    }
  }

  String? _getToken(BuildContext context) {
    return context.read<AuthProvider>().accessToken;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    context.read<BusProvider>().unsubscribeFromLiveLocations();
    super.dispose();
  }

  Color _crowdColor(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.high:     return const Color(0xFFDC2626);
      case CrowdLevel.moderate: return const Color(0xFFF59E0B);
      case CrowdLevel.low:      return const Color(0xFF16A34A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<BusProvider>(builder: (context, busProvider, _) {
        final liveBuses = busProvider.nearbyBuses
            .where((b) => b.currentLat != null && b.currentLng != null)
            .toList();
        final selectedBus = busProvider.selectedBus;

        return Column(children: [
          Expanded(child: Stack(children: [

            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userLocation,
                initialZoom: 13.0,
                onMapReady: () {
                  setState(() => _mapReady = true);
                  // If GPS resolved before map was ready, move now
                  if (_gotGps) {
                    _mapController.move(_userLocation, 14.0);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  userAgentPackageName: 'com.busgo.client',
                ),

                MarkerLayer(markers: [
                  Marker(
                    point: _userLocation,
                    width: 30, height: 30,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) {
                        final scale = 1.0 + _pulseController.value * 0.4;
                        return Stack(alignment: Alignment.center, children: [
                          Transform.scale(scale: scale,
                            child: Container(width: 30, height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.secondary.withValues(
                                    alpha: 0.2 * (1 - _pulseController.value))))),
                          Container(width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(
                                  color: AppColors.secondary.withValues(alpha: 0.6),
                                  blurRadius: 8)])),
                        ]);
                      }),
                  ),
                ]),

                MarkerLayer(markers: liveBuses.map((bus) {
                  final pos = LatLng(bus.currentLat!, bus.currentLng!);
                  final isSelected = selectedBus?.busId == bus.busId;
                  final color = _crowdColor(bus.crowdLevel);

                  return Marker(
                    point: pos,
                    width: isSelected ? 56 : 48,
                    height: isSelected ? 56 : 48,
                    child: GestureDetector(
                      onTap: () {
                        if (isSelected) {
                          busProvider.clearSelection();
                          context.read<TripProvider>().stopEtaPolling();
                        } else {
                          busProvider.selectBus(bus);
                          _mapController.move(pos, 15.0);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.8),
                              width: isSelected ? 3 : 2),
                          boxShadow: [BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: isSelected ? 16 : 8,
                              offset: const Offset(0, 3))],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.directions_bus,
                                size: 18, color: Colors.white),
                            Text(bus.routeNumber,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          ]),
                      ),
                    ),
                  );
                }).toList()),
              ],
            ),

            Positioned(top: 0, left: 0, right: 0,
              child: SafeArea(bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16, offset: const Offset(0, 4))]),
                    child: const Row(children: [
                      Icon(Icons.search, size: 18, color: Color(0xFF999999)),
                      SizedBox(width: 8),
                      Text('Search stops or routes...',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF999999))),
                    ]))))),

            if (liveBuses.isEmpty && !busProvider.isLoading)
              Positioned(top: 80, left: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8)]),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'No active buses with GPS in your area',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    )),
                  ]),
                )),

            if (busProvider.isLoading)
              Positioned(top: 80, right: 16,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8)]),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ))),

            Positioned(right: 12, bottom: 70,
              child: Column(children: [
                _zoomButton(Icons.add_rounded, () {
                  final z = _mapController.camera.zoom;
                  _mapController.move(
                      _mapController.camera.center, (z + 1).clamp(3, 18));
                }),
                Container(width: 40, height: 1,
                    color: const Color(0xFF1A6FA8).withValues(alpha: 0.3)),
                _zoomButton(Icons.remove_rounded, () {
                  final z = _mapController.camera.zoom;
                  _mapController.move(
                      _mapController.camera.center, (z - 1).clamp(3, 18));
                }),
              ])),

            Positioned(bottom: 12, right: 12,
              child: GestureDetector(
                onTap: () => _mapController.move(_userLocation, 13.0),
                child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.4),
                        blurRadius: 12, offset: const Offset(0, 4))]),
                  child: const Icon(Icons.my_location,
                      color: Colors.white, size: 18)))),

            Positioned(bottom: 60, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.circle, size: 6, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${liveBuses.length} BUS${liveBuses.length == 1 ? '' : 'ES'} LIVE',
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 0.5)),
                ]))),
          ])),

          if (selectedBus != null) _buildBottomSheet(selectedBus),
        ]);
      }),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
        child: Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A5C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF1A6FA8).withValues(alpha: 0.4)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8)]),
          alignment: Alignment.center,
          child: Icon(icon, color: const Color(0xFF5BB8F5), size: 22)));

  Widget _buildBottomSheet(BusModel bus) {
    final color = _crowdColor(bus.crowdLevel);

    return Consumer<TripProvider>(
      builder: (context, tripProvider, _) {

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final token = _getToken(context);
          if (token == null || bus.busId == null) return;
          final stopId = await _getDestinationStopId(bus.routeId);
          if (stopId == null || !mounted) return;
          tripProvider.startEtaPolling(
            busId:       bus.busId!,
            stopId:      stopId,
            accessToken: token,
          );
        });

        final etaMin   = tripProvider.etaMinutes ?? bus.etaMinutes;
        final etaLabel = etaMin <= 1
            ? 'Arriving now'
            : 'Arriving in $etaMin min';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20, offset: const Offset(0, -4))]),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            Container(width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2))),

            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: bus.routeColor,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(bus.routeNumber,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bus.displayRoute,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: Color(0xFF1A3A5C))),
                  const SizedBox(height: 2),
                  Text('Driver: ${bus.driverName}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
                ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (tripProvider.etaLoading && tripProvider.etaMinutes == null)
                  const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Text('$etaMin',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A))),
                const Text('MIN', style: TextStyle(
                    fontSize: 9, color: Color(0xFF6B7280))),
              ]),
            ]),

            const SizedBox(height: 10),

            if (tripProvider.etaMinutes != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.blue.shade600, Colors.blue.shade400]),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.access_time_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(etaLabel,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w600))),
                  if (_etaContextLabel(tripProvider.etaContext) != null)
                    Text(_etaContextLabel(tripProvider.etaContext)!,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11)),
                  if (tripProvider.etaLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))),
                ]),
              ),

            if (bus.speedKmh != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  Row(children: [
                    const Icon(Icons.speed_rounded,
                        size: 14, color: Color(0xFF1A6FA8)),
                    const SizedBox(width: 4),
                    Text('${bus.speedKmh!.toStringAsFixed(0)} km/h',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: Color(0xFF1A6FA8))),
                  ]),
                  Container(width: 1, height: 16,
                      color: const Color(0xFFE5E7EB)),
                  Row(children: [
                    Icon(Icons.circle, size: 8, color: color),
                    const SizedBox(width: 4),
                    Text(
                      bus.crowdLevel == CrowdLevel.high ? 'Crowded'
                          : bus.crowdLevel == CrowdLevel.moderate
                              ? 'Moderate' : 'Available',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: color)),
                  ]),
                  if (bus.busNumber != null) Row(children: [
                    const Icon(Icons.directions_bus,
                        size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text(bus.busNumber!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ]),
                ]),
              ),

            CrowdIndicator(
              level: bus.crowdLevel,
              customLabel: 'Passenger Load: ${bus.passengerLoad}',
            ),
          ]),
        );
      },
    );
  }

  String? _etaContextLabel(String? context) {
    switch (context) {
      case 'peak_hour': return '⚠️ Peak hour';
      case 'full_skip': return '🚌 Express';
      default:          return null;
    }
  }
}



