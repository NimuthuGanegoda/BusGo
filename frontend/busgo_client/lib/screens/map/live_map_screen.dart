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
import 'package:go_router/go_router.dart';

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

  StreamSubscription<Position>? _positionStream;

  List<Map<String, dynamic>> _busStops = [];
  bool _stopsLoaded = false;

  // ── Route polyline state ──────────────────────────────────────────────────
  List<LatLng> _routePolyline = [];
  String?      _loadedRouteId;

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
      context.read<BusProvider>().subscribeToLiveLocations();
      _pollTimer = Timer.periodic(
          const Duration(seconds: 5), (_) => _loadBuses(silent: true));
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
        _loadBusStops();
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
        _loadBusStops();
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
            _loadBusStops();
          } catch (_) {}
        }
      }

      _positionStream?.cancel();
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      _positionStream = Geolocator.getPositionStream(
              locationSettings: locationSettings)
          .listen((Position pos) {
        if (!mounted) return;
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
      }, onError: (e) {
        debugPrint('[LiveMap] Position stream error: $e');
      });

    } catch (e) {
      debugPrint('[GPS] Location error: $e');
    }
  }

  Future<void> _loadBusStops() async {
    if (_stopsLoaded) return;
    try {
      final lat   = _userLocation.latitude;
      final lng   = _userLocation.longitude;
      const delta = 0.045;

      final result = await Supabase.instance.client
          .from('bus_stops')
          .select('id, stop_name, latitude, longitude')
          .gte('latitude',  lat - delta)
          .lte('latitude',  lat + delta)
          .gte('longitude', lng - delta)
          .lte('longitude', lng + delta)
          .limit(100);

      if (mounted) {
        setState(() {
          _busStops    = List<Map<String, dynamic>>.from(result);
          _stopsLoaded = false;
        });
      }
    } catch (e) {
      debugPrint('[Stops] Load error: $e');
    }
  }

  // ── Route drawing ─────────────────────────────────────────────────────────
  Future<void> _drawRoute(BusModel bus) async {
    if (bus.routeId == null) return;
    if (_loadedRouteId == bus.routeId) return;

    try {
      final route = await context.read<BusProvider>()
          .fetchRouteById(bus.routeId!);

      List<LatLng> points = _parseWaypoints(route['waypoints']);

      if (points.isEmpty) {
        final stops = await context.read<BusProvider>()
            .fetchRouteStops(bus.routeId!);
        points = stops
            .where((s) => s.latitude != null && s.longitude != null)
            .map((s) => LatLng(s.latitude!, s.longitude!))
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _routePolyline = points;
        _loadedRouteId = bus.routeId;
      });

      if (points.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No route data available for now'),
            backgroundColor: Color(0xFF1A3A5C),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Route] $e');
    }
  }

  List<LatLng> _parseWaypoints(dynamic waypoints) {
    if (waypoints == null) return [];
    try {
      if (waypoints is List) {
        return waypoints.map((wp) {
          if (wp is Map) {
            final lat = (wp['lat']      as num?)?.toDouble()
                     ?? (wp['latitude'] as num?)?.toDouble();
            final lng = (wp['lng']       as num?)?.toDouble()
                     ?? (wp['longitude'] as num?)?.toDouble();
            if (lat != null && lng != null) return LatLng(lat, lng);
          } else if (wp is List && wp.length >= 2) {
            return LatLng(
              (wp[1] as num).toDouble(),
              (wp[0] as num).toDouble(),
            );
          }
          return null;
        }).whereType<LatLng>().toList();
      } else if (waypoints is Map && waypoints['type'] == 'LineString') {
        final coords = waypoints['coordinates'] as List?;
        if (coords != null) {
          return coords.map((c) {
            if (c is List && c.length >= 2) {
              return LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              );
            }
            return null;
          }).whereType<LatLng>().toList();
        }
      }
    } catch (e) {
      debugPrint('[Waypoints] $e');
    }
    return [];
  }

  void _clearRoute() {
    setState(() {
      _routePolyline = [];
      _loadedRouteId = null;
    });
  }

  // ── Returns the ID of the bus stop closest to the user's location ─────────
  String? _findNearestStopId() {
    if (_busStops.isEmpty) return null;
    String? nearestId;
    double  minDist = double.infinity;
    for (final stop in _busStops) {
      final lat = (stop['latitude']  as num?)?.toDouble();
      final lng = (stop['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final d = _haversine(
        _userLocation.latitude, _userLocation.longitude,
        lat, lng,
      );
      if (d < minDist) {
        minDist   = d;
        nearestId = stop['id'] as String?;
      }
    }
    return nearestId;
  }

  // ─────────────────────────────────────────────────────────────────────────

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

  String? _getToken(BuildContext context) =>
      context.read<AuthProvider>().accessToken;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _positionStream?.cancel();
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

  // ── Bus detail popup card ─────────────────────────────────────────────────
  Widget _busDetailCard(BusModel bus) {
    final crowdColor = _crowdColor(bus.crowdLevel);
    final rating     = bus.driverRating;
    final hasRating  = rating > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5),
              blurRadius: 24, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // ── Handle ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2))),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Row 1: Bus number + route + dismiss ──────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF4ECDC4).withOpacity(0.5))),
                child: Text(bus.busNumber ?? bus.routeNumber,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w800, color: Color(0xFF4ECDC4))),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('Route ${bus.routeNumber}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8))),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  context.read<BusProvider>().clearSelection();
                  context.read<TripProvider>().stopEtaPolling();
                  _clearRoute();
                },
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, size: 16,
                      color: Colors.white.withOpacity(0.6)),
                ),
              ),
            ]),

            const SizedBox(height: 10),

            // ── Row 2: Route name (from → to) ────────────────────────────────
            if (bus.from.isNotEmpty && bus.to.isNotEmpty)
              Row(children: [
                Icon(Icons.route_rounded, size: 14,
                    color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 6),
                Expanded(child: Text('${bus.from}  →  ${bus.to}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.75)))),
              ]),

            // ── ETA row ───────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Consumer<TripProvider>(
              builder: (context, tripProvider, _) {
                final eta     = tripProvider.etaMinutes;
                final loading = tripProvider.etaLoading;
                if (eta == null && !loading) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF4ECDC4).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: Color(0xFF4ECDC4)),
                    const SizedBox(width: 8),
                    Text('ETA to nearest stop',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6))),
                    const Spacer(),
                    loading
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4ECDC4)))
                        : Text('~$eta min',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4ECDC4))),
                  ]),
                );
              },
            ),

            const SizedBox(height: 14),

            // ── Row 3: Rating + Crowd ────────────────────────────────────────
            Row(children: [

              Expanded(child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DRIVER RATING', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.4), letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(hasRating ? rating.toStringAsFixed(1) : 'N/A',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: hasRating ? Colors.amber : Colors.white.withOpacity(0.4))),
                    if (hasRating) ...[
                      const SizedBox(width: 2),
                      Text('/10', style: TextStyle(
                          fontSize: 11, color: Colors.white.withOpacity(0.4))),
                    ],
                  ]),
                  if (!hasRating)
                    Text('No ratings yet', style: TextStyle(
                        fontSize: 10, color: Colors.white.withOpacity(0.35))),
                ]),
              )),

              const SizedBox(width: 10),

              Expanded(child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PASSENGERS', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.4), letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${bus.passengerCount}',
                        style: TextStyle(fontSize: 20,
                            fontWeight: FontWeight.w800, color: crowdColor)),
                    Text('/${bus.capacity}',
                        style: TextStyle(fontSize: 12,
                            color: Colors.white.withOpacity(0.4))),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (bus.passengerCount / bus.capacity).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(crowdColor),
                      minHeight: 5,
                    ),
                  ),
                ]),
              )),
            ]),

            const SizedBox(height: 10),

            // ── Row 4: Driver name + Speed ───────────────────────────────────
            Row(children: [
              Icon(Icons.person_rounded, size: 14,
                  color: Colors.white.withOpacity(0.4)),
              const SizedBox(width: 6),
              Expanded(child: Text(bus.driverName,
                  style: TextStyle(fontSize: 12,
                      color: Colors.white.withOpacity(0.6)))),
              if (bus.speedKmh != null && bus.speedKmh! > 0) ...[
                Icon(Icons.speed_rounded, size: 14,
                    color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text('${bus.speedKmh!.toStringAsFixed(0)} km/h',
                    style: TextStyle(fontSize: 12,
                        color: Colors.white.withOpacity(0.6))),
              ],
            ]),
          ]),
        ),
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
                onTap: (_, __) {
                  if (busProvider.selectedBus != null) {
                    busProvider.clearSelection();
                    context.read<TripProvider>().stopEtaPolling();
                    _clearRoute();
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  userAgentPackageName: 'com.busgo.client',
                ),

                // ── Route polyline ────────────────────────────────────────
                if (_routePolyline.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points:      _routePolyline,
                        color:       const Color(0xFF4ECDC4),
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),

                // ── User location marker ──────────────────────────────────
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

                // ── Bus stop markers ──────────────────────────────────────
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

                // ── Live bus markers ──────────────────────────────────────
                MarkerLayer(markers: liveBuses.map((bus) {
                  final pos        = LatLng(bus.currentLat!, bus.currentLng!);
                  final isSelected = selectedBus?.busId == bus.busId;
                  final color      = _crowdColor(bus.crowdLevel);
                  final rating     = bus.driverRating;

                  final markerH = rating > 0
                      ? (isSelected ? 82.0 : 74.0)
                      : (isSelected ? 60.0 : 52.0);

                  return Marker(
                    point: pos,
                    width:  isSelected ? 64.0 : 56.0,
                    height: markerH,
                    child: GestureDetector(
                      onTap: () {
                        if (isSelected) {
                          busProvider.clearSelection();
                          context.read<TripProvider>().stopEtaPolling();
                          _clearRoute();
                        } else {
                          busProvider.selectBus(bus);
                          _mapController.move(pos, 15.0);
                          _loadBuses(silent: true);
                          _drawRoute(bus);

                          // ── Start ML ETA polling to nearest stop ──────
                          final stopId = _findNearestStopId();
                          final token  = _getToken(context);
                          if (bus.busId != null &&
                              stopId != null &&
                              token  != null) {
                            context.read<TripProvider>().startEtaPolling(
                              busId:       bus.busId!,
                              stopId:      stopId,
                              accessToken: token,
                            );
                          }
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (rating > 0) _ratingBadge(rating),
                          if (rating > 0) const SizedBox(height: 2),
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

            // ── Search bar ────────────────────────────────────────────────
            Positioned(top: 0, left: 0, right: 0,
              child: SafeArea(bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: GestureDetector(
                    onTap: () => context.go('/search'),
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
                      ])))))),

            // ── Bus detail popup card ─────────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              bottom: selectedBus != null ? 0 : -300,
              left: 0, right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: selectedBus != null ? 1.0 : 0.0,
                child: selectedBus != null
                    ? _busDetailCard(selectedBus)
                    : const SizedBox.shrink(),
              ),
            ),
          ])),
        ]);
      }),
    );
  }
}