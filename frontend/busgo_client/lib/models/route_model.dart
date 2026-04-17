import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class BusRoute {
  // ── API fields ─────────────────────────────────────────────────────────────
  final String? id;
  final bool isActive;
  final List<LatLng> waypoints;

  // ── UI fields (unchanged for zero screen impact) ───────────────────────────
  final String routeNumber;
  final String from;
  final String to;
  final int stopCount;
  final int durationMinutes;
  final int etaMinutes;
  final Color routeColor;

  const BusRoute({
    this.id,
    this.isActive = true,
    this.waypoints = const [],
    required this.routeNumber,
    required this.from,
    required this.to,
    this.stopCount = 0,
    this.durationMinutes = 0,
    this.etaMinutes = 0,
    required this.routeColor,
  });

  String get displayRoute => '$from → $to';
  String get info =>
      stopCount > 0 ? '$stopCount stops · ~$durationMinutes min' : '~$durationMinutes min';

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    final colorHex = json['color'] as String? ?? '#1565C0';
    Color color;
    try {
      final h = colorHex.replaceAll('#', '');
      color = Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      color = const Color(0xFF1565C0);
    }

    // Parse waypoints if present (used by live map)
    final rawWaypoints = json['waypoints'] as List<dynamic>? ?? [];
    final waypoints = rawWaypoints.map((w) {
      final wp = w as Map<String, dynamic>;
      return LatLng(
        (wp['lat'] as num).toDouble(),
        (wp['lng'] as num).toDouble(),
      );
    }).toList();

    return BusRoute(
      id:              json['id']           as String?,
      isActive:        json['is_active']    as bool? ?? true,
      waypoints:       waypoints,
      routeNumber:     json['route_number'] as String? ?? '',
      from:            json['origin']       as String? ?? '',
      to:              json['destination']  as String? ?? '',
      stopCount:       json['stop_count']   as int? ?? 0,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      etaMinutes:      json['eta_minutes']  as int? ?? 0,
      routeColor:      color,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':           id,
        'route_number': routeNumber,
        'origin':       from,
        'destination':  to,
        'is_active':    isActive,
      };
}
