class RatingModel {
  // ── API fields ─────────────────────────────────────────────────────────────
  final String? id;
  final String? tripId;
  final String? userId;
  final String? busId;
  final String? createdAt;

  // ── UI fields (unchanged for zero screen impact) ───────────────────────────
  final String tripRouteNumber;
  final String driverName;
  final String driverId;
  final int rating;
  final List<String> tags;
  final String comment;
  final String date;

  const RatingModel({
    this.id,
    this.tripId,
    this.userId,
    this.busId,
    this.createdAt,
    required this.tripRouteNumber,
    required this.driverName,
    required this.driverId,
    required this.rating,
    required this.tags,
    this.comment = '',
    required this.date,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    // Nested objects from API
    final trip = json['trips'] as Map<String, dynamic>?;
    final bus  = json['buses'] as Map<String, dynamic>?;
    final tripRoute = trip?['bus_routes'] as Map<String, dynamic>?;

    final routeNum  = tripRoute?['route_number'] as String?
                   ?? json['tripRouteNumber']     as String? ?? '---';
    final driverName = bus?['driver_name']        as String?
                    ?? json['driverName']          as String? ?? 'Driver';
    final driverId   = bus?['id']                 as String?
                    ?? json['driverId']            as String? ?? 'DRV-0000';

    final createdAt = json['created_at'] as String? ?? json['date'] as String?;
    String date = json['date'] as String? ?? '';
    if (date.isEmpty && createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        const months = ['Jan','Feb','Mar','Apr','May','Jun',
                        'Jul','Aug','Sep','Oct','Nov','Dec'];
        date = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
      }
    }

    return RatingModel(
      id:              json['id']         as String?,
      tripId:          json['trip_id']    as String?,
      userId:          json['user_id']    as String?,
      busId:           json['bus_id']     as String?,
      createdAt:       createdAt,
      tripRouteNumber: routeNum,
      driverName:      driverName,
      driverId:        driverId,
      rating:          json['stars']      as int?
                    ?? json['rating']     as int? ?? 0,
      tags:            (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      comment:         json['comment']    as String? ?? '',
      date:            date,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':             id,
        'trip_id':        tripId,
        'bus_id':         busId,
        'stars':          rating,
        'tags':           tags,
        'comment':        comment,
        'tripRouteNumber': tripRouteNumber,
        'driverName':     driverName,
        'driverId':       driverId,
        'date':           date,
      };
}
