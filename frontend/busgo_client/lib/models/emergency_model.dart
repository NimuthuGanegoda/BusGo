class EmergencyAlertModel {
  // ── API fields ─────────────────────────────────────────────────────────────
  final String? id;
  final String? userId;
  final String? busId;
  final String? tripId;
  final String? alertType;   // 'medical'|'criminal'|'breakdown'|'harassment'|'other'
  final double? latitude;
  final double? longitude;
  final String? alertStatus; // 'pending'|'acknowledged'|'resolved'
  final String? createdAt;
  final String? updatedAt;

  // ── UI fields (unchanged for zero screen impact) ───────────────────────────
  final String type;
  final String details;
  final String date;
  final String status;

  const EmergencyAlertModel({
    this.id,
    this.userId,
    this.busId,
    this.tripId,
    this.alertType,
    this.latitude,
    this.longitude,
    this.alertStatus,
    this.createdAt,
    this.updatedAt,
    required this.type,
    this.details = '',
    required this.date,
    this.status = 'Sent',
  });

  factory EmergencyAlertModel.fromJson(Map<String, dynamic> json) {
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

    // Map API alert_type to display label
    final rawType = json['alert_type'] as String? ?? json['type'] as String? ?? 'other';
    final displayType = _typeToDisplay(rawType);

    // Map API status to display label
    final rawStatus = json['status'] as String? ?? 'pending';
    final displayStatus = _statusToDisplay(rawStatus);

    return EmergencyAlertModel(
      id:          json['id']           as String?,
      userId:      json['user_id']      as String?,
      busId:       json['bus_id']       as String?,
      tripId:      json['trip_id']      as String?,
      alertType:   rawType,
      latitude:    (json['latitude']    as num?)?.toDouble(),
      longitude:   (json['longitude']   as num?)?.toDouble(),
      alertStatus: rawStatus,
      createdAt:   createdAt,
      updatedAt:   json['updated_at']   as String?,
      type:        displayType,
      details:     json['description']  as String? ?? json['details'] as String? ?? '',
      date:        date,
      status:      displayStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':          id,
        'alert_type':  alertType ?? _displayToType(type),
        'description': details,
        'status':      alertStatus ?? 'pending',
        'type':        type,
        'details':     details,
        'date':        date,
      };

  static String _typeToDisplay(String raw) {
    switch (raw.toLowerCase()) {
      case 'medical':    return '🏥 Medical Emergency';
      case 'criminal':   return '🔪 Criminal Activity';
      case 'breakdown':  return '🔧 Bus Breakdown';
      case 'harassment': return '😰 Harassment';
      default:           return '📢 Other';
    }
  }

  static String _displayToType(String display) {
    if (display.contains('Medical'))    return 'medical';
    if (display.contains('Criminal'))   return 'criminal';
    if (display.contains('Breakdown'))  return 'breakdown';
    if (display.contains('Harassment')) return 'harassment';
    return 'other';
  }

  static String _statusToDisplay(String raw) {
    switch (raw.toLowerCase()) {
      case 'acknowledged': return 'Acknowledged';
      case 'resolved':     return 'Resolved';
      default:             return 'Sent';
    }
  }
}
