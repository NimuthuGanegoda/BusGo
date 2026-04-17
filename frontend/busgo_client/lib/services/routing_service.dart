import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service that fetches real road geometries from the OSRM public API.
///
/// Given a list of waypoints it returns a high-resolution polyline
/// that follows actual roads, suitable for drawing on a map and
/// animating bus movement.
class RoutingService {
  RoutingService._();

  static const String _baseUrl = 'router.project-osrm.org';

  /// Fetch a road-snapped route between [waypoints].
  ///
  /// Returns a dense `List<LatLng>` that follows real roads.
  /// Falls back to the original [waypoints] if the API call fails.
  static Future<List<LatLng>> fetchRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return waypoints;

    try {
      // Build coordinate string: lng,lat;lng,lat;...
      final coords = waypoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');

      final uri = Uri.https(
        _baseUrl,
        '/route/v1/driving/$coords',
        {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        return waypoints; // fallback
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['code'] != 'Ok') {
        return waypoints; // fallback
      }

      final routes = json['routes'] as List<dynamic>;
      if (routes.isEmpty) return waypoints;

      final geometry =
          routes[0]['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;

      // GeoJSON coordinates are [lng, lat]
      final result = coordinates.map<LatLng>((coord) {
        final c = coord as List<dynamic>;
        return LatLng(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        );
      }).toList();

      return result.length >= 2 ? result : waypoints;
    } catch (_) {
      // Network error, timeout, parse error → fallback
      return waypoints;
    }
  }

  /// Fetch multiple routes in parallel.
  ///
  /// Each entry in [waypointSets] is a list of waypoints for one route.
  /// Returns a list of road-snapped polylines in the same order.
  static Future<List<List<LatLng>>> fetchRoutes(
    List<List<LatLng>> waypointSets,
  ) async {
    final futures = waypointSets.map(fetchRoute).toList();
    return Future.wait(futures);
  }
}
