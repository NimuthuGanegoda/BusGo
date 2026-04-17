import 'package:shared_preferences/shared_preferences.dart';

/// Thin persistence layer — stores only UI preferences and local search cache.
/// All user data, trips, ratings and emergency alerts now live in the API.
class LocalStorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Keys ───────────────────────────────────────────────────────────────────
  static const _keyNotifBusArrival    = 'notif_bus_arrival';
  static const _keyNotifServiceUpdates = 'notif_service_updates';
  static const _keyNotifPromotions    = 'notif_promotions';

  // ── Notification Preferences ───────────────────────────────────────────────
  static bool getBusArrivalAlerts() =>
      _prefs.getBool(_keyNotifBusArrival) ?? true;
  static bool getServiceUpdates() =>
      _prefs.getBool(_keyNotifServiceUpdates) ?? true;
  static bool getPromotions() =>
      _prefs.getBool(_keyNotifPromotions) ?? false;

  static Future<void> setBusArrivalAlerts(bool v) =>
      _prefs.setBool(_keyNotifBusArrival, v);
  static Future<void> setServiceUpdates(bool v) =>
      _prefs.setBool(_keyNotifServiceUpdates, v);
  static Future<void> setPromotions(bool v) =>
      _prefs.setBool(_keyNotifPromotions, v);

  // ── Clear All ──────────────────────────────────────────────────────────────
  static Future<void> clearAll() => _prefs.clear();
}
