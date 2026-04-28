/// Base URLs — switch by changing kBaseUrl
/// Emulator:    http://10.0.2.2:5000/api
/// Real device: http://192.168.1.3:5000/api
/// Production:  https://api.busgo.lk/api
const String kBaseUrlDev  = 'http://192.168.1.3:5000/api';
const String kBaseUrlProd = 'https://your-api-domain.com/api';

/// All API endpoint paths
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const register      = '/auth/register';
  static const login         = '/auth/login';
  static const logout        = '/auth/logout';
  static const refresh       = '/auth/refresh';
  static const forgotRequest = '/auth/forgot-password/request';
  static const forgotVerify  = '/auth/forgot-password/verify';
  static const forgotReset   = '/auth/forgot-password/reset';

  // Users
  static const me            = '/users/me';
  static const myStats       = '/users/me/stats';
  static const myPreferences = '/users/me/preferences';
  static const myAvatar      = '/users/me/avatar';

  // QR
  static const qrCard        = '/qr/my-card';
  static const qrScanExit    = '/qr/scan-exit';

  // Buses
  static const nearbyBuses              = '/buses/nearby';
  static String busById(String id)      => '/buses/$id';
  static String busLocation(String id)  => '/buses/$id/location';
  static String busCrowd(String id)     => '/buses/$id/crowd';

  // Routes
  static const busRoutes                 = '/routes?waypoints=false';
  static const routeSearch               = '/routes/search';
  static String routeById(String id)     => '/routes/$id';
  static String routeStops(String id)    => '/routes/$id/stops';
  static String routeBuses(String id)    => '/routes/$id/buses';

  // Stops
  static const stops                     = '/stops';
  static const nearbyStops               = '/stops/nearby';
  static String stopById(String id)      => '/stops/$id';

  // Trips
  static const trips                     = '/trips';
  static String tripById(String id)      => '/trips/$id';
  static String tripAlight(String id)    => '/trips/$id/alight';

  // Ratings
  static const ratings                   = '/ratings';
  static String busRatings(String busId) => '/ratings/bus/$busId';

  // Emergency
  static const emergency                       = '/emergency';
  static String emergencyStatus(String id)     => '/emergency/$id/status';

  // Notifications
  static const notifications                   = '/notifications';
  static const notificationsReadAll            = '/notifications/read-all';
  static String notificationRead(String id)    => '/notifications/$id/read';
  static String notificationDelete(String id)  => '/notifications/$id';

  // Searches
  static const recentSearches = '/searches/recent';
}





