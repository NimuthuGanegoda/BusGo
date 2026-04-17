import 'package:flutter/material.dart';
import '../core/utils/helpers.dart';

class BusModel {
  // ── API fields ─────────────────────────────────────────────────────────────
  final String? busId;
  final String? routeId;
  final String? busNumber;
  final String? driverPhone;
  final double? currentLat;
  final double? currentLng;
  final double? heading;
  final double? speedKmh;
  final String? busStatus;         // 'active' | 'inactive' | 'breakdown'
  final String? lastLocationUpdate;
  final double? distanceKm;        // Haversine distance from user

  // ── UI fields (kept for zero screen changes) ───────────────────────────────
  final String routeNumber;
  final String routeName;
  final String from;
  final String to;
  final String stopId;
  final String stopName;
  final double distance;
  final int etaMinutes;
  final CrowdLevel crowdLevel;
  final Color routeColor;
  final String driverName;
  final String driverId;
  final double driverRating;
  final int passengerCount;
  final int capacity;

  const BusModel({
    this.busId,
    this.routeId,
    this.busNumber,
    this.driverPhone,
    this.currentLat,
    this.currentLng,
    this.heading,
    this.speedKmh,
    this.busStatus,
    this.lastLocationUpdate,
    this.distanceKm,
    required this.routeNumber,
    required this.routeName,
    required this.from,
    required this.to,
    required this.stopId,
    required this.stopName,
    required this.distance,
    required this.etaMinutes,
    required this.crowdLevel,
    required this.routeColor,
    this.driverName = 'Kamal Perera',
    this.driverId = 'DRV-0000',
    this.driverRating = 4.0,
    this.passengerCount = 15,
    this.capacity = 40,
  });

  String get displayRoute => '$from → $to';
  String get stopInfo => '$stopName · ${distance.toStringAsFixed(1)} km';
  String get passengerLoad => '$passengerCount/$capacity';

  // ── Serialization ──────────────────────────────────────────────────────────

  factory BusModel.fromJson(Map<String, dynamic> json) {
    // Nested route data
    final route = json['bus_routes'] as Map<String, dynamic>?;
    final routeNum  = route?['route_number'] as String? ?? json['route_number'] as String? ?? '---';
    final routeName = route?['route_name']   as String? ?? json['route_name']   as String? ?? '';
    final origin    = route?['origin']       as String? ?? json['origin']       as String? ?? '';
    final dest      = route?['destination']  as String? ?? json['destination']  as String? ?? '';
    final colorHex  = route?['color']        as String? ?? json['color']        as String? ?? '#1565C0';

    final distKm    = (json['distance_km'] as num?)?.toDouble() ?? 0.0;
    final speed     = (json['speed_kmh']   as num?)?.toDouble() ?? 0.0;

    // Compute ETA: distance / speed in minutes, fall back to distance-based estimate.
    int eta;
    if (speed > 0) {
      eta = (distKm / speed * 60).round().clamp(1, 999);
    } else {
      eta = (distKm * 5).round().clamp(1, 999); // rough: 12 km/h avg
    }

    final crowd = _parseCrowd(json['crowd_level'] as String? ?? 'low');
    final color = _parseColor(colorHex);

    final driverId = json['id'] as String? ?? json['bus_id'] as String? ?? 'DRV-0000';

    return BusModel(
      busId:               json['id']                    as String?,
      routeId:             json['route_id']              as String?,
      busNumber:           json['bus_number']            as String?,
      driverPhone:         json['driver_phone']          as String?,
      currentLat:          (json['current_lat']  as num?)?.toDouble(),
      currentLng:          (json['current_lng']  as num?)?.toDouble(),
      heading:             (json['heading']       as num?)?.toDouble(),
      speedKmh:            (json['speed_kmh']    as num?)?.toDouble(),
      busStatus:           json['status']                as String?,
      lastLocationUpdate:  json['last_location_update']  as String?,
      distanceKm:          distKm,
      // UI fields
      routeNumber:   routeNum,
      routeName:     routeName,
      from:          origin,
      to:            dest,
      stopId:        json['id'] as String? ?? driverId,
      stopName:      origin.isNotEmpty ? '$origin Stop' : 'Nearby Stop',
      distance:      distKm,
      etaMinutes:    eta,
      crowdLevel:    crowd,
      routeColor:    color,
      driverName:    json['driver_name'] as String? ?? 'Driver',
      driverId:      driverId,
      driverRating:  4.0,
      passengerCount: _crowdToPassengers(crowd),
      capacity:       40,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static CrowdLevel _parseCrowd(String raw) {
    switch (raw.toLowerCase()) {
      case 'high':
      case 'full': return CrowdLevel.high;
      case 'medium': return CrowdLevel.moderate;
      default:       return CrowdLevel.low;
    }
  }

  static Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF1565C0);
    }
  }

  static int _crowdToPassengers(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.high:     return 35;
      case CrowdLevel.moderate: return 22;
      case CrowdLevel.low:      return 10;
    }
  }

  /// Copy with updated real-time location from Supabase Realtime.
  BusModel copyWithLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speedKmh,
  }) =>
      BusModel(
        busId: busId, routeId: routeId, busNumber: busNumber,
        driverPhone: driverPhone,
        currentLat: lat, currentLng: lng,
        heading: heading ?? this.heading,
        speedKmh: speedKmh ?? this.speedKmh,
        busStatus: busStatus, lastLocationUpdate: DateTime.now().toIso8601String(),
        distanceKm: distanceKm,
        routeNumber: routeNumber, routeName: routeName,
        from: from, to: to, stopId: stopId, stopName: stopName,
        distance: distance, etaMinutes: etaMinutes,
        crowdLevel: crowdLevel, routeColor: routeColor,
        driverName: driverName, driverId: driverId,
        driverRating: driverRating,
        passengerCount: passengerCount, capacity: capacity,
      );
}
