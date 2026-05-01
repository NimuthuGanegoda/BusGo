import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class BusRoute {
  final String id;
  final String routeNumber;
  final String name;
  final String from;
  final String to;
  final int totalStops;
  final double distanceKm;
  final int estimatedMinutes;
  final Color color;
  final List<RouteStop> stops;
  final List<LatLng> polyline;
  final bool isAssigned;
  final String schedule;

  const BusRoute({
    required this.id, required this.routeNumber, required this.name,
    required this.from, required this.to, required this.totalStops,
    required this.distanceKm, required this.estimatedMinutes,
    required this.color, this.stops = const [], this.polyline = const [],
    this.isAssigned = false, this.schedule = '',
  });

  String get displayName => '$routeNumber — $name';
  String get routeDirection => '$from → $to';
  String get distanceDisplay => '${distanceKm.toStringAsFixed(1)} km';
  String get durationDisplay {
    if (estimatedMinutes < 60) return '${estimatedMinutes}m';
    final h = estimatedMinutes ~/ 60;
    final m = estimatedMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}

class RouteStop {
  final String id;
  final String name;
  final LatLng location;
  final int sequence;
  final bool isCompleted;

  const RouteStop({
    required this.id, required this.name, required this.location,
    required this.sequence, this.isCompleted = false,
  });
}







