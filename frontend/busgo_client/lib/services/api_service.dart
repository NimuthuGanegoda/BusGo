import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.8.101:5000';

  Future<Map<String, dynamic>?> fetchETA({
    required String busId,
    required String stopId,
    required String accessToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/eta/bus/$busId/stop/$stopId'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // Backend wraps response in {success, data, message}
        // Extract the data field which contains eta_minutes
        final data = body['data'] as Map<String, dynamic>?;
        return data;
      }
      debugPrint('ETA error: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('ETA fetch error: $e');
      return null;
    }
  }
}
