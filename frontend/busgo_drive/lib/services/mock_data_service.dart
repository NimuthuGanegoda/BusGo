import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/driver_model.dart';
import '../models/route_model.dart';

class MockDataService {
  MockDataService._();

  static const Driver currentDriver = Driver(
    id: 'DRV-2841', employeeId: 'EMP-4521', name: 'Kamal Perera',
    email: 'kamal.perera@busgo.lk', phone: '+94 77 123 4567',
    licenseNumber: 'B-2847561', licenseExpiry: '2027-08-15',
    rating: 0.0, tripsCompleted: 0, hoursLogged: 1248, status: 'active',
    vehicleId: 'VH-2841', vehiclePlate: 'WP-KA-5523',
    vehicleModel: 'Ashok Leyland Viking',
  );

  static final List<BusRoute> routes = [
    BusRoute(
      id: 'RT-001', routeNumber: '138', name: 'Kaduwela – Colombo Fort',
      from: 'Kaduwela', to: 'Colombo Fort', totalStops: 18,
      distanceKm: 22.4, estimatedMinutes: 65,
      color: const Color(0xFF0D47A1), isAssigned: true,
      schedule: '06:00, 08:30, 11:00, 14:00, 17:00',
      stops: [
        RouteStop(id: 'S001', name: 'Kaduwela Bus Stand',  location: LatLng(6.9320, 79.8828), sequence: 1),
        RouteStop(id: 'S002', name: 'Malabe Junction',     location: LatLng(6.9147, 79.8886), sequence: 2),
        RouteStop(id: 'S003', name: 'Battaramulla',        location: LatLng(6.9020, 79.8922), sequence: 3),
        RouteStop(id: 'S004', name: 'Rajagiriya',          location: LatLng(6.9065, 79.8768), sequence: 4),
        RouteStop(id: 'S005', name: 'Borella Junction',    location: LatLng(6.9147, 79.8715), sequence: 5),
        RouteStop(id: 'S006', name: 'Maradana',            location: LatLng(6.9298, 79.8653), sequence: 6),
        RouteStop(id: 'S007', name: 'Colombo Fort',        location: LatLng(6.9344, 79.8500), sequence: 7),
      ],
      polyline: [
        LatLng(6.9320, 79.8828), LatLng(6.9270, 79.8860),
        LatLng(6.9147, 79.8886), LatLng(6.9080, 79.8900),
        LatLng(6.9020, 79.8922), LatLng(6.9065, 79.8768),
        LatLng(6.9147, 79.8715), LatLng(6.9298, 79.8653), LatLng(6.9344, 79.8500),
      ],
    ),
    BusRoute(
      id: 'RT-002', routeNumber: '177', name: 'Kottawa – Pettah',
      from: 'Kottawa', to: 'Pettah', totalStops: 22,
      distanceKm: 28.6, estimatedMinutes: 80,
      color: const Color(0xFF2E7D32), isAssigned: true,
      schedule: '05:30, 07:00, 09:30, 12:00, 15:30',
      stops: [
        RouteStop(id: 'S101', name: 'Kottawa Bus Stand', location: LatLng(6.8410, 79.9622), sequence: 1),
        RouteStop(id: 'S102', name: 'Pannipitiya',       location: LatLng(6.8600, 79.9510), sequence: 2),
        RouteStop(id: 'S103', name: 'Maharagama',        location: LatLng(6.8480, 79.9280), sequence: 3),
        RouteStop(id: 'S104', name: 'Nugegoda',          location: LatLng(6.8638, 79.8889), sequence: 4),
        RouteStop(id: 'S105', name: 'Kirulapone',        location: LatLng(6.8820, 79.8780), sequence: 5),
        RouteStop(id: 'S106', name: 'Pettah',            location: LatLng(6.9355, 79.8520), sequence: 6),
      ],
      polyline: [
        LatLng(6.8410, 79.9622), LatLng(6.8600, 79.9510),
        LatLng(6.8480, 79.9280), LatLng(6.8638, 79.8889),
        LatLng(6.8820, 79.8780), LatLng(6.9355, 79.8520),
      ],
    ),
  ];
}







