import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/config/api_config.dart';
import '../models/route_model.dart';
import '../services/token_service.dart';

class RouteProvider extends ChangeNotifier {
  List<BusRoute> _routes        = [];
  BusRoute?      _selectedRoute;
  BusRoute?      _assignedRoute; // ← the driver's specific assigned route
  bool           _isLoading     = false;
  String?        _error;

  List<BusRoute> get routes          => _routes;
  List<BusRoute> get assignedRoutes  => _routes.where((r) => r.isAssigned).toList();
  List<BusRoute> get availableRoutes => _routes.where((r) => !r.isAssigned).toList();
  BusRoute?      get selectedRoute   => _selectedRoute;
  BusRoute?      get assignedRoute   => _assignedRoute;
  bool           get isLoading       => _isLoading;
  String?        get error           => _error;

  // ── Load the specific route assigned to this driver ────────────────────────
  // Calls GET /driver/bus which returns the bus with its nested bus_routes
  // including full waypoints. This is the correct approach — each driver
  // only loads their own route, not all routes.
  Future<void> loadDriverAssignedRoute() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final token = await TokenService().getAccessToken();
      if (token == null) {
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/driver/bus'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;

        if (data != null) {
          final busRoutes = data['bus_routes'] as Map<String, dynamic>?;
          if (busRoutes != null) {
            _assignedRoute = _parseRouteFromBus(busRoutes);
            _routes        = [_assignedRoute!];
            debugPrint('[RouteProvider] Assigned route: '
                '${_assignedRoute!.routeNumber} — '
                '${_assignedRoute!.name} '
                '(${_assignedRoute!.polyline.length} waypoints, '
                '${_assignedRoute!.stops.length} stops)');
          } else {
            debugPrint('[RouteProvider] No route assigned to this driver');
          }
        }
      } else {
        _error = 'Failed to load assigned route (${res.statusCode})';
        debugPrint('[RouteProvider] Error: $_error');
      }
    } catch (e) {
      _error = 'Connection error: $e';
      debugPrint('[RouteProvider] Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Also keep loadRoutes for any backward compatibility ────────────────────
  Future<void> loadRoutes() async {
    await loadDriverAssignedRoute();
  }

  BusRoute _parseRouteFromBus(Map<String, dynamic> j) {
    // ── Color ──────────────────────────────────────────────────────────────
    Color routeColor = Colors.blue;
    final colorStr = j['color'] as String?;
    if (colorStr != null && colorStr.startsWith('#')) {
      try {
        routeColor = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    // ── Waypoints → polyline ───────────────────────────────────────────────
    final List<LatLng> polyline = [];
    final rawWaypoints = j['waypoints'];
    if (rawWaypoints is List) {
      for (final wp in rawWaypoints) {
        if (wp is Map) {
          final lat = (wp['lat'] as num?)?.toDouble();
          final lng = (wp['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            polyline.add(LatLng(lat, lng));
          }
        }
      }
    }

    // ── Stops ──────────────────────────────────────────────────────────────
    final List<RouteStop> stops = [];
    final rawStops = j['bus_stop_routes'] as List<dynamic>?;
    if (rawStops != null) {
      final sorted = rawStops
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) =>
            ((a['stop_order'] as int?) ?? 0)
                .compareTo((b['stop_order'] as int?) ?? 0));

      for (final s in sorted) {
        final busStop = s['bus_stops'] as Map<String, dynamic>?;
        if (busStop == null) continue;
        final lat = (busStop['latitude']  as num?)?.toDouble();
        final lng = (busStop['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        stops.add(RouteStop(
          id:       busStop['id']        as String? ?? '',
          name:     busStop['stop_name'] as String? ?? 'Stop',
          location: LatLng(lat, lng),
          sequence: (s['stop_order']     as int?)  ?? 0,
        ));
      }
    }

    return BusRoute(
      id:               j['id']           as String? ?? '',
      routeNumber:      j['route_number'] as String? ?? '?',
      name:             j['route_name']   as String? ?? '',
      from:             j['origin']       as String? ?? '',
      to:               j['destination']  as String? ?? '',
      totalStops:       stops.length,
      distanceKm:       0,
      estimatedMinutes: 0,
      color:            routeColor,
      stops:            stops,
      polyline:         polyline,
      isAssigned:       true,
    );
  }

  void selectRoute(BusRoute route) {
    _selectedRoute = route;
    notifyListeners();
  }

  void clearSelection() {
    _selectedRoute = null;
    notifyListeners();
  }
}