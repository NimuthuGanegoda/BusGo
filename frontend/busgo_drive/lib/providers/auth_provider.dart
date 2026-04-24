import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/api_config.dart';
import '../models/driver_model.dart';
import '../services/token_service.dart';

class AuthProvider extends ChangeNotifier {
  Driver?      _driver;
  bool         _isLoading = false;
  String?      _error;
  final TokenService _tokenService = TokenService();

  Driver?  get driver     => _driver;
  bool     get isLoggedIn => _driver != null;
  bool     get isLoading  => _isLoading;
  String?  get error      => _error;

  Future<String?> getToken() => _tokenService.getAccessToken();

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    // ── Retry logic: try up to 2 times on network failure ──
    const maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        ).timeout(const Duration(seconds: 15)); // increased from 10s

        final body = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode == 429) {
          _error = 'TOO_MANY_REQUESTS';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        if (response.statusCode == 423) {
          _error = 'ACCOUNT_LOCKED';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        if (response.statusCode == 403) {
          final code = body['code'] ?? '';
          _error = code == 'PENDING_APPROVAL' ? 'PENDING_APPROVAL' : 'LOGIN_RESTRICTED';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        if (response.statusCode != 200 && response.statusCode != 201) {
          _error = 'INVALID_CREDENTIALS';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final data = body['data'] as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>;

        // ── Role restriction: only drivers can use this app ──
        // Generic message — does NOT reveal what type of account it is
        if (user['role'] != 'driver') {
          _error = 'LOGIN_RESTRICTED';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        await _tokenService.saveTokens(
          data['access_token']  as String,
          data['refresh_token'] as String,
        );

        _driver = Driver(
          id:             user['id']        as String,
          employeeId:     user['id']        as String,
          name:           user['full_name'] as String,
          email:          user['email']     as String,
          phone:          user['phone']     as String? ?? '',
          licenseNumber:  'B-0000000',
          licenseExpiry:  '2027-01-01',
          rating:         0.0,
          tripsCompleted: 0,
          hoursLogged:    0,
        );

        // ── Reset bus to inactive on login ────────────────────────
        try {
          await Supabase.instance.client
              .from('buses')
              .update({
                'status': 'inactive',
                'current_lat': null,
                'current_lng': null,
                'last_location_update': null,
                'speed_kmh': 0,
              })
              .eq('driver_user_id', _driver!.id);
          debugPrint('[Login] Bus reset to inactive ✅');
        } catch (e) {
          debugPrint('[Login] Bus reset error: $e');
        }

        _isLoading = false;
        notifyListeners();
        return true;

      } catch (e) {
        debugPrint('[Login] Attempt $attempt failed: $e');
        // If not the last attempt, wait briefly and retry
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }
        // Last attempt failed
        _error = 'CONNECTION_FAILED';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }

    // Should never reach here, but just in case
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> checkExistingSession() async {
    return _tokenService.hasToken();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> logout() async {
    // ── Reset bus to inactive on logout ───────────────────────
    try {
      if (_driver != null) {
        await Supabase.instance.client
            .from('buses')
            .update({
              'status': 'inactive',
              'current_lat': null,
              'current_lng': null,
              'last_location_update': null,
              'speed_kmh': 0,
            })
            .eq('driver_user_id', _driver!.id);
        debugPrint('[Logout] Bus reset to inactive ✅');
      }
    } catch (e) {
      debugPrint('[Logout] Bus reset error: $e');
    }

    try {
      final token   = await _tokenService.getAccessToken();
      final refresh = await _tokenService.getRefreshToken();
      if (token != null) {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
          headers: {
            'Content-Type':  'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'refresh_token': refresh}),
        ).timeout(const Duration(seconds: 5));
      }
    } catch (_) {}

    await _tokenService.clearTokens();
    _driver = null;
    notifyListeners();
  }
}
