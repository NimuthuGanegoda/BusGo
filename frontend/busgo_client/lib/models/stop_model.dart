class StopModel {
  // ── API fields ─────────────────────────────────────────────────────────────
  final String? id;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;   // populated by /stops/nearby

  // ── UI fields (unchanged for zero screen impact) ───────────────────────────
  final String stopId;
  final String name;
  final double distance;
  final List<String> routes;

  const StopModel({
    this.id,
    this.latitude,
    this.longitude,
    this.distanceKm,
    required this.stopId,
    required this.name,
    required this.distance,
    required this.routes,
  });

  String get distanceDisplay => '${distance.toStringAsFixed(1)} km';
  String get routesDisplay => routes.isNotEmpty ? 'Routes: ${routes.join(', ')}' : 'No routes';
  String get info => '$distanceDisplay · $routesDisplay';

  factory StopModel.fromJson(Map<String, dynamic> json) {
    // Route numbers from nested bus_stop_routes → bus_routes
    final rawRoutes = json['routes'] as List<dynamic>?;
    List<String> routeNumbers = [];
    if (rawRoutes != null) {
      for (final r in rawRoutes) {
        if (r is Map<String, dynamic>) {
          final num = r['route_number'] as String?;
          if (num != null) routeNumbers.add(num);
        } else if (r is String) {
          routeNumbers.add(r);
        }
      }
    }

    final distKm = (json['distance_km'] as num?)?.toDouble() ?? 0.0;
    final sid = json['id'] as String? ?? '';

    return StopModel(
      id:          sid,
      latitude:    (json['latitude']  as num?)?.toDouble(),
      longitude:   (json['longitude'] as num?)?.toDouble(),
      distanceKm:  distKm,
      stopId:      sid,
      name:        json['stop_name'] as String? ?? '',
      distance:    distKm,
      routes:      routeNumbers,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':        id,
        'stop_name': name,
        'latitude':  latitude,
        'longitude': longitude,
      };
}
