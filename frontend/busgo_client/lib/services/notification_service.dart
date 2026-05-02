import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../services/token_service.dart';

/// Handles local push notifications for bus arrival alerts.
/// System tray notification works offline.
/// DB insert goes via backend (192.168.1.3:5000) using the app's own JWT.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  static const int _startStopId = 1001;
  static const int _endStopId   = 1002;

  // ── Initialise (call once in main.dart) ───────────────────────────────────
  Future<void> init() async {
    if (_initialised) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS:     iosSettings,
    );

    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialised = true;
    debugPrint('[NotificationService] Initialised ✅');
  }

  // ── Show system tray notification ─────────────────────────────────────────
  Future<void> _show({
    required int    id,
    required String title,
    required String body,
  }) async {
    if (!_initialised) await init();

    const androidDetails = AndroidNotificationDetails(
      'busgo_arrivals',
      'Bus Arrivals',
      channelDescription: 'Notifications when your bus is near a stop',
      importance:         Importance.high,
      priority:           Priority.high,
      playSound:          true,
      enableVibration:    true,
      icon:               '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS:     iosDetails,
    );

    await _plugin.show(id, title, body, details);
    debugPrint('[NotificationService] Showed: $title');
  }

  // ── Save to DB via backend ────────────────────────────────────────────────
  Future<void> _saveToDb({
    required String title,
    required String body,
    required String category,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final token = await TokenService().getAccessToken();
      if (token == null) {
        debugPrint('[NotificationService] No token — skipping DB save');
        return;
      }

      final response = await http.post(
        Uri.parse('$kBaseUrlDev/notifications'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'category': category,
          'title':    title,
          'body':     body,
          'meta':     meta ?? {},
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        debugPrint('[NotificationService] Saved to DB ✅');
      } else {
        debugPrint('[NotificationService] Backend ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[NotificationService] DB save error: $e');
    }
  }

  // ── Public helpers ────────────────────────────────────────────────────────

  Future<void> notifyBusArrivingAtStart(
      String stopName, String routeNumber) async {
    final title = '🚌 Bus $routeNumber is arriving!';
    final body  = 'Your bus is approaching $stopName. Get ready to board!';
    await _show(id: _startStopId, title: title, body: body);
    await _saveToDb(
      title:    title,
      body:     body,
      category: 'bus_alert',
      meta:     {'route_number': routeNumber, 'stop_name': stopName},
    );
  }

  Future<void> notifyBusArrivingAtEnd(
      String stopName, String routeNumber) async {
    final title = '📍 Approaching your stop!';
    final body  = 'Bus $routeNumber is near $stopName. Prepare to alight.';
    await _show(id: _endStopId, title: title, body: body);
    await _saveToDb(
      title:    title,
      body:     body,
      category: 'bus_alert',
      meta:     {'route_number': routeNumber, 'stop_name': stopName},
    );
  }

  // ── Haversine distance (metres) ───────────────────────────────────────────
  static double distanceMetres(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const R    = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a    = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * asin(sqrt(a));
  }
}








