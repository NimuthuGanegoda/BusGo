import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../services/token_service.dart';

class LocationService {
  final TokenService _tokenService = TokenService();

  Future<void> updateLocation({
    required double lat,
    required double lng,
    required double speedKmh,
    double? heading,
  }) async {
    final token = await _tokenService.getAccessToken();
    if (token == null) {
      debugPrint('[LocationService] No token — skipping location update');
      return;
    }

    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/driver/location'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lat':       lat,
          'lng':       lng,
          'speed_kmh': speedKmh.clamp(0, 200),
          if (heading != null) 'heading': heading,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[LocationService] Updated: lat=$lat lng=$lng speed=${speedKmh.toStringAsFixed(1)}km/h');
      } else {
        debugPrint('[LocationService] Backend error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[LocationService] Network error: $e');
    }
  }
}
