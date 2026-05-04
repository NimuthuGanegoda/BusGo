import '../core/utils/helpers.dart';

class Trip {
  final String id;
  final String routeId;
  final String routeNumber;
  final String routeName;
  final String driverId;
  final DateTime startTime;
  final DateTime? endTime;
  final int passengersBoarded;
  final int passengersAlighted;
  final int currentPassengers;
  final int stopsCompleted;
  final int totalStops;
  final double distanceCovered;
  final double totalDistance;
  final double avgSpeed;
  final TripStatus status;

  const Trip({
    required this.id, required this.routeId, required this.routeNumber,
    required this.routeName, required this.driverId, required this.startTime,
    this.endTime, this.passengersBoarded = 0, this.passengersAlighted = 0,
    this.currentPassengers = 0, this.stopsCompleted = 0,
    required this.totalStops, this.distanceCovered = 0,
    required this.totalDistance, this.avgSpeed = 0, this.status = TripStatus.active,
  });

  String get duration {
    final end = endTime ?? DateTime.now();
    final diff = end.difference(startTime);
    return Helpers.formatDuration(diff.inMinutes);
  }

  double get progress => totalStops > 0 ? stopsCompleted / totalStops : 0;
  String get passengerDisplay => '$currentPassengers';

  Trip copyWith({
    int? passengersBoarded, int? passengersAlighted, int? currentPassengers,
    int? stopsCompleted, double? distanceCovered, double? avgSpeed,
    TripStatus? status, DateTime? endTime,
  }) => Trip(
    id: id, routeId: routeId, routeNumber: routeNumber, routeName: routeName,
    driverId: driverId, startTime: startTime,
    endTime: endTime ?? this.endTime,
    passengersBoarded: passengersBoarded ?? this.passengersBoarded,
    passengersAlighted: passengersAlighted ?? this.passengersAlighted,
    currentPassengers: currentPassengers ?? this.currentPassengers,
    stopsCompleted: stopsCompleted ?? this.stopsCompleted,
    totalStops: totalStops,
    distanceCovered: distanceCovered ?? this.distanceCovered,
    totalDistance: totalDistance,
    avgSpeed: avgSpeed ?? this.avgSpeed,
    status: status ?? this.status,
  );
}










