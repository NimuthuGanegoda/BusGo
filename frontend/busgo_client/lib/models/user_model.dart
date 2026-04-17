class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String username;
  final String phone;
  final String? dateOfBirth;
  final String? avatarUrl;
  final String membershipType;
  final String memberSince;
  final int totalTrips;
  final bool isActive;
  // QR fields (from backend)
  final String? qrToken;
  final String? qrExpiresAt;
  // Legacy field kept for QR screen compatibility
  final String qrCode;
  final String? createdAt;
  final String? updatedAt;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.username = '',
    this.phone = '',
    this.dateOfBirth,
    this.avatarUrl,
    this.membershipType = 'Standard Member',
    this.memberSince = 'Jan 2024',
    this.totalTrips = 0,
    this.isActive = true,
    this.qrToken,
    this.qrExpiresAt,
    this.qrCode = '',
    this.createdAt,
    this.updatedAt,
  });

  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  String get validUntil => '12 / 2026';

  /// Derive a display-friendly membership label from the raw type string.
  String get membershipLabel {
    switch (membershipType.toLowerCase()) {
      case 'premium': return 'Premium Member';
      case 'student': return 'Student Member';
      default:        return 'Standard Member';
    }
  }

  Map<String, dynamic> toJson() => {
        'id':             id,
        'full_name':      fullName,
        'email':          email,
        'username':       username,
        'phone':          phone,
        'date_of_birth':  dateOfBirth,
        'avatar_url':     avatarUrl,
        'membership_type': membershipType,
        'member_since':   memberSince,
        'total_trips':    totalTrips,
        'is_active':      isActive,
        'qr_token':       qrToken,
        'qr_expires_at':  qrExpiresAt,
        'qr_code':        qrCode,
        'created_at':     createdAt,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Support both snake_case (API) and camelCase (legacy local storage).
    final createdAt = json['created_at'] as String?;
    final memberSince = _deriveMemberSince(createdAt);

    return UserModel(
      id:             json['id'] as String? ?? '',
      fullName:       (json['full_name'] ?? json['fullName']) as String? ?? '',
      email:          json['email'] as String? ?? '',
      username:       (json['username']) as String? ?? '',
      phone:          (json['phone']) as String? ?? '',
      dateOfBirth:    (json['date_of_birth'] ?? json['dateOfBirth']) as String?,
      avatarUrl:      (json['avatar_url'] ?? json['avatarUrl']) as String?,
      membershipType: (json['membership_type'] ?? json['membershipType']) as String? ?? 'standard',
      memberSince:    (json['member_since'] ?? json['memberSince']) as String? ?? memberSince,
      totalTrips:     (json['total_trips'] ?? json['totalTrips']) as int? ?? 0,
      isActive:       (json['is_active'] ?? json['isActive']) as bool? ?? true,
      qrToken:        (json['qr_token'] ?? json['qrToken']) as String?,
      qrExpiresAt:    (json['qr_expires_at'] ?? json['qrExpiresAt']) as String?,
      qrCode:         (json['qr_token'] ?? json['qrCode'] ?? '') as String,
      createdAt:      createdAt,
      updatedAt:      json['updated_at'] as String?,
    );
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? username,
    String? phone,
    String? dateOfBirth,
    String? avatarUrl,
    String? membershipType,
    String? memberSince,
    int? totalTrips,
    bool? isActive,
    String? qrToken,
    String? qrExpiresAt,
    String? qrCode,
    String? createdAt,
    String? updatedAt,
  }) =>
      UserModel(
        id:             id             ?? this.id,
        fullName:       fullName       ?? this.fullName,
        email:          email          ?? this.email,
        username:       username       ?? this.username,
        phone:          phone          ?? this.phone,
        dateOfBirth:    dateOfBirth    ?? this.dateOfBirth,
        avatarUrl:      avatarUrl      ?? this.avatarUrl,
        membershipType: membershipType ?? this.membershipType,
        memberSince:    memberSince    ?? this.memberSince,
        totalTrips:     totalTrips     ?? this.totalTrips,
        isActive:       isActive       ?? this.isActive,
        qrToken:        qrToken        ?? this.qrToken,
        qrExpiresAt:    qrExpiresAt    ?? this.qrExpiresAt,
        qrCode:         qrCode         ?? this.qrCode,
        createdAt:      createdAt      ?? this.createdAt,
        updatedAt:      updatedAt      ?? this.updatedAt,
      );

  static String _deriveMemberSince(String? isoDate) {
    if (isoDate == null) return 'Jan 2024';
    try {
      final dt = DateTime.parse(isoDate);
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'Jan 2024';
    }
  }
}
