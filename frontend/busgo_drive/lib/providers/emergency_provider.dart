import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../models/alert_model.dart';
import '../services/token_service.dart';

class EmergencyProvider extends ChangeNotifier {
  Alert?  _activeAlert;
  String? _selectedType;
  String  _description = '';
  bool    _isSending   = false;
  bool    _isSent      = false;
  String? _error;

  final TokenService _tokenService = TokenService();

  Alert?  get activeAlert    => _activeAlert;
  String? get selectedType   => _selectedType;
  String  get description    => _description;
  bool    get isSending      => _isSending;
  bool    get isSent         => _isSent;
  bool    get hasActiveAlert => _activeAlert != null;
  String? get error          => _error;

  void selectType(String type) {
    _selectedType = type;
    notifyListeners();
  }

  void setDescription(String desc) {
    _description = desc;
  }

  Future<void> sendAlert({
    required String driverId,
    required String tripId,
    required double latitude,
    required double longitude,
    String? busId,   // ← added
  }) async {
    if (_selectedType == null) return;
    _isSending = true;
    _error     = null;
    notifyListeners();

    final token = await _tokenService.getAccessToken();
    if (token == null) {
      _error     = 'Not logged in — please log in again';
      _isSending = false;
      _isSent    = false;
      notifyListeners();
      return;
    }

    try {
      final typeMap = {
        'medical':   'medical',
        'breakdown': 'breakdown',
        'criminal':  'criminal',
        'accident':  'other',
        'other':     'other',
      };

      // Build request body — include bus_id and trip_id so the backend
      // can store them on the emergency_alerts record
      final requestBody = <String, dynamic>{
        'alert_type':  typeMap[_selectedType] ?? 'other',
        'description': _description.isEmpty
            ? 'Emergency alert from driver'
            : _description,
        'latitude':  latitude,
        'longitude': longitude,
      };

      // Only include if valid — avoids sending 'NO-TRIP' or 'DRV-UNKNOWN'
      // as real UUIDs which would cause a DB error
      if (busId != null && busId.isNotEmpty && busId != 'UNKNOWN') {
        requestBody['bus_id'] = busId;
      }
      if (tripId.isNotEmpty && tripId != 'NO-TRIP') {
        requestBody['trip_id'] = tripId;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/emergency'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data      = jsonDecode(response.body);
        final alertData = data['data'] as Map<String, dynamic>? ?? {};

        _activeAlert = Alert(
          id:          alertData['id']          as String? ?? 'ALR-${DateTime.now().millisecondsSinceEpoch}',
          type:        alertData['alert_type']  as String? ?? _selectedType!,
          description: alertData['description'] as String? ?? _description,
          driverId:    driverId,
          tripId:      tripId,
          latitude:    latitude,
          longitude:   longitude,
          timestamp:   DateTime.now(),
          status:      AlertStatus.sent,
        );
        _isSent = true;
        _error  = null;
      } else {
        final body = jsonDecode(response.body);
        _error  = body['message'] as String? ?? 'Failed to send alert (${response.statusCode})';
        _isSent = false;
        debugPrint('[Emergency] Backend error ${response.statusCode}: $_error');
      }
    } catch (e) {
      _error  = 'Network error — please check your connection';
      _isSent = false;
      debugPrint('[Emergency] Network error: $e');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void cancelAlert() {
    _activeAlert = null;
    _isSent      = false;
    notifyListeners();
  }

  void reset() {
    _activeAlert  = null;
    _selectedType = null;
    _description  = '';
    _isSending    = false;
    _isSent       = false;
    _error        = null;
    notifyListeners();
  }
}


