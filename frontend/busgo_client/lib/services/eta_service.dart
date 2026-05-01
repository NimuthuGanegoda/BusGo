import '../core/constants/api_constants.dart';
import 'api_client.dart';

/// Result of an ETA prediction from the backend (which calls ML Model 2).
class EtaResult {
  final String busId;
  final String busNumber;
  final double etaMinutes;
  final double etaSeconds;
  final double distanceKm;
  final int stopsRemaining;
  final String calculatedAt;
  final Map<String, dynamic> context;

  const EtaResult({
    required this.busId,
    required this.busNumber,
    required this.etaMinutes,
    required this.etaSeconds,
    required this.distanceKm,
    required this.stopsRemaining,
    required this.calculatedAt,
    required this.context,
  });

  factory EtaResult.fromJson(Map<String, dynamic> json) => EtaResult(
    busId:          json['bus_id'] as String? ?? '',
    busNumber:      json['bus_number'] as String? ?? '',
    etaMinutes:     (json['eta_minutes'] as num?)?.toDouble() ?? 0.0,
    etaSeconds:     (json['eta_seconds'] as num?)?.toDouble() ?? 0.0,
    distanceKm:     (json['distance_km'] as num?)?.toDouble() ?? 0.0,
    stopsRemaining: json['stops_remaining'] as int? ?? 0,
    calculatedAt:   json['calculated_at'] as String? ?? '',
    context:        (json['context'] as Map<String, dynamic>?) ?? {},
  );

  /// Human-readable ETA string e.g. "~4 min" or "~1 hr 5 min"
  String get displayEta {
    if (etaMinutes < 1) return '< 1 min';
    if (etaMinutes < 60) return '~${etaMinutes.round()} min';
    final h = (etaMinutes / 60).floor();
    final m = (etaMinutes % 60).round();
    return m > 0 ? '~$h hr $m min' : '~$h hr';
  }
}

class EtaService {
  final ApiClient _api;
  EtaService(this._api);

  /// GET /eta/bus/:busId/stop/:stopId
  /// Returns how many minutes until [busId] reaches [stopId].
  Future<EtaResult> getBusEta(
    String busId,
    String stopId, {
    bool isRaining = false,
  }) async {
    final data = await _api.get(
      ApiEndpoints.busEta(busId, stopId),
      queryParameters: {'is_raining': isRaining.toString()},
    );
    return EtaResult.fromJson(data as Map<String, dynamic>);
  }

  /// GET /eta/route/:routeId/stop/:stopId
  /// Returns ETAs for ALL buses on the route, sorted nearest first.
  Future<List<EtaResult>> getRouteEtas(
    String routeId,
    String stopId, {
    bool isRaining = false,
  }) async {
    final data = await _api.get(
      ApiEndpoints.routeEta(routeId, stopId),
      queryParameters: {'is_raining': isRaining.toString()},
    );
    final list = data as List<dynamic>;
    return list
        .map((e) => EtaResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}







