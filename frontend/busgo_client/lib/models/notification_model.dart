class NotificationModel {
  // ── API fields ─────────────────────────────────────────────────────────────
  final String? id;
  final String? userId;
  final String? type;    // 'trip_complete'|'rating_reminder'|'system'|'promo'
  final bool isRead;
  final String? createdAt;

  // ── UI fields ──────────────────────────────────────────────────────────────
  final String title;
  final String body;
  final String date;

  const NotificationModel({
    this.id,
    this.userId,
    this.type,
    this.isRead = false,
    this.createdAt,
    required this.title,
    required this.body,
    required this.date,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
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

    return NotificationModel(
      id:        json['id']         as String?,
      userId:    json['user_id']    as String?,
      type:      json['type']       as String?,
      isRead:    json['is_read']    as bool? ?? false,
      createdAt: createdAt,
      title:     json['title']      as String? ?? '',
      body:      json['body']       as String? ?? json['message'] as String? ?? '',
      date:      date,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':      id,
        'type':    type,
        'is_read': isRead,
        'title':   title,
        'body':    body,
        'date':    date,
      };

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id:        id,
        userId:    userId,
        type:      type,
        isRead:    isRead ?? this.isRead,
        createdAt: createdAt,
        title:     title,
        body:      body,
        date:      date,
      );
}
