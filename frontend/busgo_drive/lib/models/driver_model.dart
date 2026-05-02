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
  final int    tripsCompleted;
  final double hoursLogged;
  final String status;
  final String vehicleId;
  final String vehiclePlate;
  final String vehicleModel;

  // ── Assigned bus & route (loaded after login) ──────────────────────────────
  final String? busId;
  final String? busNumber;
  final String? assignedRouteId;
  final String? assignedRouteNumber;
  final String? assignedRouteName;
  final String? assignedRouteOrigin;
  final String? assignedRouteDestination;

  const Driver({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.phone,
    required this.licenseNumber,
    required this.licenseExpiry,
    this.photoUrl            = '',
    this.rating              = 0.0,
    this.tripsCompleted      = 0,
    this.hoursLogged         = 0,
    this.status              = 'active',
    this.vehicleId           = '',
    this.vehiclePlate        = '',
    this.vehicleModel        = '',
    this.busId               = null,
    this.busNumber           = null,
    this.assignedRouteId     = null,
    this.assignedRouteNumber = null,
    this.assignedRouteName   = null,
    this.assignedRouteOrigin = null,
    this.assignedRouteDestination = null,
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  String get ratingDisplay => rating.toStringAsFixed(1);

  bool get hasBusAssigned => busId != null;

  Driver copyWith({
    String? busId,
    String? busNumber,
    String? assignedRouteId,
    String? assignedRouteNumber,
    String? assignedRouteName,
    String? assignedRouteOrigin,
    String? assignedRouteDestination,
  }) => Driver(
    id:                    id,
    employeeId:            employeeId,
    name:                  name,
    email:                 email,
    phone:                 phone,
    licenseNumber:         licenseNumber,
    licenseExpiry:         licenseExpiry,
    photoUrl:              photoUrl,
    rating:                rating,
    tripsCompleted:        tripsCompleted,
    hoursLogged:           hoursLogged,
    status:                status,
    vehicleId:             vehicleId,
    vehiclePlate:          vehiclePlate,
    vehicleModel:          vehicleModel,
    busId:                 busId               ?? this.busId,
    busNumber:             busNumber           ?? this.busNumber,
    assignedRouteId:       assignedRouteId     ?? this.assignedRouteId,
    assignedRouteNumber:   assignedRouteNumber ?? this.assignedRouteNumber,
    assignedRouteName:     assignedRouteName   ?? this.assignedRouteName,
    assignedRouteOrigin:   assignedRouteOrigin ?? this.assignedRouteOrigin,
    assignedRouteDestination: assignedRouteDestination ?? this.assignedRouteDestination,
  );
}




