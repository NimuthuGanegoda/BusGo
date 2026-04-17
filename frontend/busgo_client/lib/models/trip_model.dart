class TripModel {
  // ── API fields ─────────────────────────────────────────────────────────────
  final String? id;
  final String? userId;
  final String? busId;
  final String? routeId;
  final String? boardingStopId;
  final String? alightingStopId;
  final String? boardedAt;
  final String? alightedAt;
  final double? fareLkr;
  final String? tripStatus;   // 'ongoing' | 'completed' | 'cancelled'

  // ── UI fields (unchanged for zero screen impact) ───────────────────────────
  final String routeNumber;
  final String from;
  final String to;
  final String date;
  final String time;
  final String duration;
  final double fare;
  final int rating;
  final String driverName;
  final String driverId;

  const TripModel({
    this.id,
    this.userId,
    this.busId,
    this.routeId,
    this.boardingStopId,
    this.alightingStopId,
    this.boardedAt,
    this.alightedAt,
    this.fareLkr,
    this.tripStatus,
    required this.routeNumber,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    this.duration = '',
    required this.fare,
    this.rating = 0,
    this.driverName = 'Driver',
    this.driverId = 'DRV-0000',
  });

  String get displayRoute => '$from → $to';
  String get fareDisplay  => 'LKR ${fare.toStringAsFixed(0)}';
  String get dateTime =>
      duration.isNotEmpty ? '$date · $time · $duration' : '$date · $time';

  factory TripModel.fromJson(Map<String, dynamic> json) {
    // Support both API (snake_case) and legacy local (camelCase) shapes.
    final boardedAt  = json['boarded_at']  as String?;
    final alightedAt = json['alighted_at'] as String?;
    final fareLkr    = (json['fare_lkr']   as num?)?.toDouble()
                     ?? (json['fare']       as num?)?.toDouble()
                     ?? 0.0;

    // Nested objects from API
    final busRoute = json['bus_routes'] as Map<String, dynamic>?;
    final bus      = json['buses']      as Map<String, dynamic>?;
    final ratingList = json['ratings']  as List<dynamic>?;
    final firstRating = ratingList != null && ratingList.isNotEmpty
        ? ratingList.first as Map<String, dynamic>
        : null;

    final routeNumber = busRoute?['route_number'] as String?
                     ?? json['routeNumber']        as String? ?? '---';
    final from  = busRoute?['origin']      as String?
               ?? json['from']             as String? ?? '';
    final to    = busRoute?['destination'] as String?
               ?? json['to']              as String? ?? '';

    // Format date/time from ISO string
    String date = json['date'] as String? ?? '';
    String time = json['time'] as String? ?? '';
    if (boardedAt != null && date.isEmpty) {
      final dt = DateTime.tryParse(boardedAt);
      if (dt != null) {
        date = _formatDate(dt);
        time = _formatTime(dt);
      }
    }

    // Compute duration from boarded_at → alighted_at
    String duration = json['duration'] as String? ?? '';
    if (duration.isEmpty && boardedAt != null && alightedAt != null) {
      final start = DateTime.tryParse(boardedAt);
      final end   = DateTime.tryParse(alightedAt);
      if (start != null && end != null) {
        duration = _formatDuration(end.difference(start));
      }
    }

    return TripModel(
      id:               json['id']               as String?,
      userId:           json['user_id']           as String?,
      busId:            json['bus_id']            as String?,
      routeId:          json['route_id']          as String?,
      boardingStopId:   json['boarding_stop_id']  as String?,
      alightingStopId:  json['alighting_stop_id'] as String?,
      boardedAt:        boardedAt,
      alightedAt:       alightedAt,
      fareLkr:          fareLkr,
      tripStatus:       json['status']            as String?,
      routeNumber:      routeNumber,
      from:             from,
      to:               to,
      date:             date,
      time:             time,
      duration:         duration,
      fare:             fareLkr,
      rating:           firstRating?['stars']     as int?
                     ?? json['rating']            as int? ?? 0,
      driverName:       bus?['driver_name']       as String?
                     ?? json['driverName']        as String? ?? 'Driver',
      driverId:         bus?['id']                as String?
                     ?? json['driverId']          as String? ?? 'DRV-0000',
    );
  }

  Map<String, dynamic> toJson() => {
        'id':            id,
        'routeNumber':   routeNumber,
        'from':          from,
        'to':            to,
        'date':          date,
        'time':          time,
        'duration':      duration,
        'fare':          fare,
        'fare_lkr':      fareLkr ?? fare,
        'rating':        rating,
        'driverName':    driverName,
        'driverId':      driverId,
        'status':        tripStatus,
        'boarded_at':    boardedAt,
        'alighted_at':   alightedAt,
      };

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  static String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _formatDuration(Duration d) {
    if (d.inHours >= 1) return '${d.inHours} hr ${d.inMinutes.remainder(60)} min';
    return '${d.inMinutes} min';
  }
}
