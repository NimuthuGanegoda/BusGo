class Driver {
  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String phone;
  final String licenseNumber;
  final String licenseExpiry;
  final String photoUrl;
  final double rating;
  final int tripsCompleted;
  final double hoursLogged;
  final String status;
  final String vehicleId;
  final String vehiclePlate;
  final String vehicleModel;

  const Driver({
    required this.id, required this.employeeId, required this.name,
    required this.email, required this.phone,
    required this.licenseNumber, required this.licenseExpiry,
    this.photoUrl = '', this.rating = 4.2, this.tripsCompleted = 487,
    this.hoursLogged = 1248, this.status = 'active',
    this.vehicleId = 'VH-2841', this.vehiclePlate = 'WP-KA-5523',
    this.vehicleModel = 'Ashok Leyland Viking',
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  String get ratingDisplay => rating.toStringAsFixed(1);
}
