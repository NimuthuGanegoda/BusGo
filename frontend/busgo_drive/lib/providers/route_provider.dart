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
  BusRoute?      _assignedRoute;
  bool           _isLoading     = false;
  String?        _error;

  List<BusRoute> get routes          => _routes;
  List<BusRoute> get assignedRoutes  => _routes.where((r) => r.isAssigned).toList();
  List<BusRoute> get availableRoutes => _routes.where((r) => !r.isAssigned).toList();
  BusRoute?      get selectedRoute   => _selectedRoute;
  BusRoute?      get assignedRoute   => _assignedRoute;
  bool           get isLoading       => _isLoading;
  String?        get error           => _error;

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

      debugPrint('[RouteProvider] /driver/bus status=${res.statusCode} bytes=${res.body.length}');

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;

        if (data != null) {
          final busRoutes = data['bus_routes'] as Map<String, dynamic>?;
          if (busRoutes != null) {
            debugPrint('[RouteProvider] bus_routes keys: ${busRoutes.keys.toList()}');
            debugPrint('[RouteProvider] waypoints type: ${busRoutes['waypoints']?.runtimeType}');
            _assignedRoute = _parseRouteFromBus(busRoutes);
            _routes        = [_assignedRoute!];
            debugPrint('[RouteProvider] ✅ Route ${_assignedRoute!.routeNumber} — '
                '${_assignedRoute!.polyline.length} waypoints, '
                '${_assignedRoute!.stops.length} stops');
          } else {
            debugPrint('[RouteProvider] ❌ bus_routes is null in response');
          }
        }
      } else {
        _error = 'Failed to load route (${res.statusCode})';
        debugPrint('[RouteProvider] Error: ${res.body}');
      }
    } catch (e) {
      _error = 'Connection error: $e';
      debugPrint('[RouteProvider] Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRoutes() async => loadDriverAssignedRoute();

  BusRoute _parseRouteFromBus(Map<String, dynamic> j) {
    Color routeColor = Colors.blue;
    final colorStr = j['color'] as String?;
    if (colorStr != null && colorStr.startsWith('#')) {
      try { routeColor = Color(int.parse(colorStr.replaceFirst('#', '0xFF'))); } catch (_) {}
    }

    // Parse waypoints — handle both jsonb (List) and text (String) column types
    final List<LatLng> polyline = [];
    dynamic raw = j['waypoints'];

    if (raw is String && raw.trim().isNotEmpty) {
      try { raw = jsonDecode(raw); } catch (e) {
        debugPrint('[RouteProvider] waypoints JSON parse failed: $e');
        raw = null;
      }
    }

    if (raw is List) {
      for (final wp in raw) {
        if (wp is Map) {
          final lat = ((wp['lat'] ?? wp['latitude']) as num?)?.toDouble();
          final lng = ((wp['lng'] ?? wp['longitude'] ?? wp['lon']) as num?)?.toDouble();
          if (lat != null && lng != null) polyline.add(LatLng(lat, lng));
        }
      }
    }
    debugPrint('[RouteProvider] Parsed ${polyline.length} waypoints (raw type: ${raw?.runtimeType})');

    // Parse stops
    final List<RouteStop> stops = [];
    final rawStops = j['bus_stop_routes'] as List<dynamic>?;
    if (rawStops != null) {
      final sorted = rawStops.whereType<Map<String, dynamic>>().toList()
        ..sort((a, b) => ((a['stop_order'] as int?) ?? 0).compareTo((b['stop_order'] as int?) ?? 0));
      for (final s in sorted) {
        final bs  = s['bus_stops'] as Map<String, dynamic>?;
        if (bs == null) continue;
        final lat = (bs['latitude']  as num?)?.toDouble();
        final lng = (bs['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        stops.add(RouteStop(
          id: bs['id'] as String? ?? '',
          name: bs['stop_name'] as String? ?? 'Stop',
          location: LatLng(lat, lng),
          sequence: (s['stop_order'] as int?) ?? 0,
        ));
      }
    }
    debugPrint('[RouteProvider] Parsed ${stops.length} stops');

    final effectivePolyline = polyline.isNotEmpty
        ? polyline
        : stops.map((s) => s.location).toList();

    return BusRoute(
      id: j['id'] as String? ?? '',
      routeNumber: j['route_number'] as String? ?? '?',
      name: j['route_name'] as String? ?? '',
      from: j['origin'] as String? ?? '',
      to: j['destination'] as String? ?? '',
      totalStops: stops.length,
      distanceKm: 0, estimatedMinutes: 0,
      color: routeColor,
      stops: stops,
      polyline: effectivePolyline,
      isAssigned: true,
    );
  }

  void selectRoute(BusRoute route) { _selectedRoute = route; notifyListeners(); }
  void clearSelection() { _selectedRoute = null; notifyListeners(); }
}
