class Alert {
  final String id;
  final String type;
  final String description;
  final String driverId;
  final String tripId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final AlertStatus status;

  const Alert({
    required this.id, required this.type, required this.description,
    required this.driverId, required this.tripId,
    required this.latitude, required this.longitude,
    required this.timestamp, this.status = AlertStatus.sent,
  });

  Alert copyWith({AlertStatus? status}) => Alert(
    id: id, type: type, description: description,
    driverId: driverId, tripId: tripId,
    latitude: latitude, longitude: longitude, timestamp: timestamp,
    status: status ?? this.status,
  );
}

enum AlertStatus { sent, acknowledged, resolved, cancelled }









