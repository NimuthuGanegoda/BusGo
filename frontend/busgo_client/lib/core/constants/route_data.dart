import 'package:latlong2/latlong.dart';

/// Real-world waypoint definitions for bus routes in the Colombo area.
///
/// These waypoints are passed to the OSRM API to generate
/// high-resolution road-snapped polylines.
/// Each route lists key stops/intersections along the real road corridor.
class RouteData {
  RouteData._();

  /// Route 138: Nugegoda → Colombo Fort
  /// Via: High Level Road → Kirulapone → Bambalapitiya → Colombo Fort
  static const route138Waypoints = [
    LatLng(6.8649, 79.8997), // Nugegoda Junction
    LatLng(6.8700, 79.8920), // Pagoda Road
    LatLng(6.8756, 79.8853), // Kirulapone Junction
    LatLng(6.8830, 79.8760), // Narahenpita area
    LatLng(6.8900, 79.8650), // Bambalapitiya
    LatLng(6.9000, 79.8580), // Kollupitiya Junction
    LatLng(6.9100, 79.8550), // Slave Island area
    LatLng(6.9271, 79.8612), // Colombo Fort
  ];

  /// Route 163: Rajagiriya → Maharagama
  /// Via: Rajagiriya → Battaramulla → Kotte → Nugegoda → Maharagama
  static const route163Waypoints = [
    LatLng(6.9120, 79.8950), // Rajagiriya Junction
    LatLng(6.9060, 79.8990), // Battaramulla
    LatLng(6.8980, 79.9010), // Sri Jayawardenepura Kotte
    LatLng(6.8900, 79.8960), // Kotte Road
    LatLng(6.8780, 79.8930), // Mirihana
    LatLng(6.8690, 79.8900), // Delkanda
    LatLng(6.8500, 79.8860), // Maharagama
  ];

  /// Route 171: Colombo 4 (Bambalapitiya) → Athurugiriya
  /// Via: Bambalapitiya → Havelock Town → Nugegoda → Kottawa → Athurugiriya
  static const route171Waypoints = [
    LatLng(6.8900, 79.8560), // Colombo 4 / Bambalapitiya
    LatLng(6.8850, 79.8650), // Havelock Town
    LatLng(6.8780, 79.8750), // Narahenpita
    LatLng(6.8700, 79.8850), // Nawala area
    LatLng(6.8650, 79.8997), // Nugegoda
    LatLng(6.8560, 79.9100), // Pannipitiya Road
    LatLng(6.8450, 79.9200), // Thalawathugoda
    LatLng(6.8400, 79.9350), // Athurugiriya
  ];

  /// Bus stops with real positions along the routes
  static const busStops = [
    // Stops on route 138
    LatLng(6.8756, 79.8853), // Kirulapone Junction
    LatLng(6.9000, 79.8580), // Kollupitiya
    // Stops on route 163
    LatLng(6.8980, 79.9010), // Sri Jayawardenepura Kotte
    LatLng(6.8690, 79.8900), // Delkanda
    // Stops on route 171
    LatLng(6.8850, 79.8650), // Havelock Town
    LatLng(6.8650, 79.8997), // Nugegoda
  ];
}
