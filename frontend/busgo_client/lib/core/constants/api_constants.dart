/// Base URLs — switch via AppConfig
const String kBaseUrlDev  = 'http://10.0.2.2:5000/api'; // Android emulator localhost
const String kBaseUrlProd = 'https://your-api-domain.com/api';

/// All API endpoint paths — single source of truth for all 3 Flutter apps
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const register       = '/auth/register';
  static const login          = '/auth/login';
  static const logout         = '/auth/logout';
  static const refresh        = '/auth/refresh';
  static const forgotRequest  = '/auth/forgot-password/request';
  static const forgotVerify   = '/auth/forgot-password/verify';
  static const forgotReset    = '/auth/forgot-password/reset';

  // Users
  static const me             = '/users/me';
  static const myStats        = '/users/me/stats';
  static const myPreferences  = '/users/me/preferences';
  static const myAvatar       = '/users/me/avatar';

  // QR
  static const qrCard         = '/qr/my-card';
  static const qrScanIn       = '/qr/scan-in';   // ← Scanner: passenger boards
  static const qrScanExit     = '/qr/scan-exit'; // ← Scanner: passenger alights

  // Buses
  static const nearbyBuses    = '/buses/nearby';
  static String busById(String id)       => '/buses/$id';
  static String busLocation(String id)   => '/buses/$id/location';
  static String busCrowd(String id)      => '/buses/$id/crowd';

  // ETA — ML Model 2
  static String busEta(String busId, String stopId)     => '/eta/bus/$busId/stop/$stopId';
  static String routeEta(String routeId, String stopId) => '/eta/route/$routeId/stop/$stopId';

  // Routes
  static const busRoutes      = '/routes';
  static const routeSearch    = '/routes/search';
  static String routeById(String id)    => '/routes/$id';
  static String routeStops(String id)   => '/routes/$id/stops';
  static String routeBuses(String id)   => '/routes/$id/buses';

  // Stops
  static const stops          = '/stops';
  static const nearbyStops    = '/stops/nearby';
  static String stopById(String id)     => '/stops/$id';

  // Trips
  static const trips          = '/trips';
  static String tripById(String id)     => '/trips/$id';
  static String tripAlight(String id)   => '/trips/$id/alight';

  // Ratings
  static const ratings        = '/ratings';
  static String busRatings(String busId) => '/ratings/bus/$busId';

  // Emergency
  static const emergency      = '/emergency';
  static String emergencyStatus(String id) => '/emergency/$id/status';

  // Notifications
  static const notifications          = '/notifications';
  static const notificationsReadAll   = '/notifications/read-all';
  static String notificationRead(String id)   => '/notifications/$id/read';
  static String notificationDelete(String id) => '/notifications/$id';

  // Searches
  static const recentSearches = '/searches/recent';

  // Driver-specific (BUSGO Drive)
  static const driverMe           = '/driver/me';
  static const driverBus          = '/driver/bus';
  static const driverRating       = '/driver/rating';
  static const driverCurrentTrip  = '/driver/trip/current';
  static const driverLocation     = '/driver/location';
  static const driverCrowd        = '/driver/crowd';
}
