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
  LatLng _userLocation = const LatLng(6.9271, 79.8612);
  late AnimationController _pulseController;
  Timer? _pollTimer;
  bool _mapReady = false;
  bool _gotGps   = false;

  // Bus stops loaded from Supabase
  List<Map<String, dynamic>> _busStops = [];
  bool _stopsLoaded = false;

  String get _tileUrl =>
      'https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png'
      '?key=${dotenv.env['MAPTILER_KEY'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
      _loadBuses();
      _loadBusStops();
      _pollTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _loadBuses(silent: true));
    });
  }

  Future<void> _initLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _userLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
          _gotGps = true;
        });
        _moveMapToUser();
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 15));
        if (!mounted) return;
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _gotGps = true;
        });
        _moveMapToUser();
      } catch (e) {
        if (!_gotGps) {
          try {
            final fallback = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
            ).timeout(const Duration(seconds: 10));
            if (!mounted) return;
            setState(() {
              _userLocation = LatLng(fallback.latitude, fallback.longitude);
              _gotGps = true;
            });
            _moveMapToUser();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[GPS] Location error: $e');
    }
  }

  // ── Load bus stops from Supabase ────────────────────────────────────────────
  Future<void> _loadBusStops() async {
    if (_stopsLoaded) return;
    try {
      final result = await Supabase.instance.client
          .from('bus_stops')
          .select('id, stop_name, latitude, longitude')
          .limit(500);
      if (mounted) {
        setState(() {
          _busStops   = List<Map<String, dynamic>>.from(result);
          _stopsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('[Stops] Load error: $e');
    }
  }

  void _moveMapToUser() {
    if (_mapReady && mounted) _mapController.move(_userLocation, 14.0);
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
    return R * 2 * asin(sqrt(a.clamp(0, 1)));
  }

  Future<String?> _getDestinationStopId(String? routeId) async {
    try {
      final stops = await Supabase.instance.client
          .from('bus_stops')
          .select('id, stop_name, latitude, longitude')
          .limit(400);
      if ((stops as List).isEmpty) return null;
      String? nearestId;
      double minDist = double.infinity;
      for (final stop in stops) {
        final lat = (stop['latitude']  as num?)?.toDouble();
        final lng = (stop['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final dist = _haversine(
            _userLocation.latitude, _userLocation.longitude, lat, lng);
        if (dist < minDist) { minDist = dist; nearestId = stop['id'] as String?; }
      }
      return nearestId;
    } catch (e) { return null; }
  }

  String? _getToken(BuildContext context) =>
      context.read<AuthProvider>().accessToken;

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

  // ── Build star rating widget ─────────────────────────────────────────────────
  Widget _ratingBadge(double? rating) {
    if (rating == null || rating <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.7), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, size: 9, color: Colors.amber),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: Colors.white)),
      ]),
    );
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
                  if (_gotGps) _mapController.move(_userLocation, 14.0);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  userAgentPackageName: 'com.busgo.client',
                ),

                // ── User location marker ─────────────────────────────────────
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
                                color: AppColors.secondary.withOpacity(
                                    0.2 * (1 - _pulseController.value))))),
                          Container(width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(
                                  color: AppColors.secondary.withOpacity(0.6),
                                  blurRadius: 8)])),
                        ]);
                      }),
                  ),
                ]),

                // ── Bus stop markers (UFR_22) ────────────────────────────────
                if (_busStops.isNotEmpty)
                  MarkerLayer(markers: _busStops.map((stop) {
                    final lat = (stop['latitude']  as num?)?.toDouble();
                    final lng = (stop['longitude'] as num?)?.toDouble();
                    if (lat == null || lng == null) {
                      return Marker(point: _userLocation,
                          width: 0, height: 0, child: const SizedBox());
                    }
                    return Marker(
                      point: LatLng(lat, lng),
                      width: 24, height: 24,
                      child: Tooltip(
                        message: stop['stop_name'] ?? '',
                        child: Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1628),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF4ECDC4), width: 2),
                            boxShadow: [BoxShadow(
                                color: const Color(0xFF4ECDC4).withOpacity(0.4),
                                blurRadius: 4)],
                          ),
                          child: const Icon(Icons.directions_bus_filled,
                              size: 10, color: Color(0xFF4ECDC4)),
                        ),
                      ),
                    );
                  }).where((m) => m.width > 0).toList()),

                // ── Live bus markers with rating badge ───────────────────────
                MarkerLayer(markers: liveBuses.map((bus) {
                  final pos       = LatLng(bus.currentLat!, bus.currentLng!);
                  final isSelected = selectedBus?.busId == bus.busId;
                  final color     = _crowdColor(bus.crowdLevel);
                  final rating    = bus.driverRating; // may be null

                  // Height increases to make room for rating badge above icon
                  final markerH = rating != null && rating > 0
                      ? (isSelected ? 74.0 : 66.0)
                      : (isSelected ? 56.0 : 48.0);

                  return Marker(
                    point: pos,
                    width:  isSelected ? 64.0 : 56.0,
                    height: markerH,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // ── Rating badge above bus icon ──────────────────
                          if (rating != null && rating > 0)
                            _ratingBadge(rating),
                          if (rating != null && rating > 0)
                            const SizedBox(height: 2),

                          // ── Bus icon ─────────────────────────────────────
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width:  isSelected ? 56 : 48,
                            height: isSelected ? 56 : 48,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.8),
                                  width: isSelected ? 3 : 2),
                              boxShadow: [BoxShadow(
                                  color: color.withOpacity(0.5),
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
                        ],
                      ),
                    ),
                  );
                }).toList()),
              ],
            ),

            // ── Search bar ─────────────────────────────────────────────────
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
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 16, offset: const Offset(0, 4))]),
                    child: const Row(children: [
                      Icon(Icons.search, size: 18, color: Color(0xFF999999)),
                      SizedBox(width: 8),
                      Text('Search stops or routes...',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF999999))),
                    ]))))),
          ])),
        ]);
      }),
    );
  }
}
