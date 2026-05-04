import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  // ── Fetch assigned bus and store route info in Driver model ────────────────
  Future<void> _fetchAssignedBus() async {
    try {
      final token = await _tokenService.getAccessToken();
      if (token == null || _driver == null) return;

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/driver/bus'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data == null) return;

        final busRoutes = data['bus_routes'] as Map<String, dynamic>?;

        _driver = _driver!.copyWith(
          busId:                    data['id']         as String?,
          busNumber:                data['bus_number'] as String?,
          assignedRouteId:          busRoutes?['id']           as String?,
          assignedRouteNumber:      busRoutes?['route_number'] as String?,
          assignedRouteName:        busRoutes?['route_name']   as String?,
          assignedRouteOrigin:      busRoutes?['origin']       as String?,
          assignedRouteDestination: busRoutes?['destination']  as String?,
        );

        debugPrint('[AuthProvider] Assigned bus: ${_driver!.busNumber} '
            'Route: ${_driver!.assignedRouteNumber} - ${_driver!.assignedRouteName}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthProvider] Failed to fetch assigned bus: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    const maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        ).timeout(const Duration(seconds: 15));

        final body = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode == 429) {
          _error = 'TOO_MANY_REQUESTS'; _isLoading = false; notifyListeners(); return false;
        }
        if (response.statusCode == 423) {
          _error = 'ACCOUNT_LOCKED'; _isLoading = false; notifyListeners(); return false;
        }
        if (response.statusCode == 403) {
          final code = body['code'] ?? '';
          _error = code == 'PENDING_APPROVAL' ? 'PENDING_APPROVAL' : 'LOGIN_RESTRICTED';
          _isLoading = false; notifyListeners(); return false;
        }
        if (response.statusCode != 200 && response.statusCode != 201) {
          _error = 'INVALID_CREDENTIALS'; _isLoading = false; notifyListeners(); return false;
        }

        final data = body['data'] as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>;

        if (user['role'] != 'driver') {
          _error = 'LOGIN_RESTRICTED'; _isLoading = false; notifyListeners(); return false;
        }

        await _tokenService.saveTokens(
          data['access_token']  as String,
          data['refresh_token'] as String,
        );

        _driver = Driver(
          id:            user['id']        as String,
          employeeId:    user['id']        as String,
          name:          user['full_name'] as String,
          email:         user['email']     as String,
          phone:         user['phone']     as String? ?? '',
          licenseNumber: 'B-0000000',
          licenseExpiry: '2027-01-01',
          rating:        0.0,
          tripsCompleted: 0,
          hoursLogged:   0,
        );

        // ── Reset bus to inactive on login via backend ─────────────────────
        try {
          final token = data['access_token'] as String;
          await http.patch(
            Uri.parse('${ApiConfig.baseUrl}/driver/status'),
            headers: {
              'Content-Type':  'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'status': 'inactive'}),
          ).timeout(const Duration(seconds: 5));
          debugPrint('[Login] Bus reset to inactive via backend ✅');
        } catch (e) {
          debugPrint('[Login] Bus reset error: $e');
        }

        _isLoading = false;
        notifyListeners();

        // ── Fetch assigned bus & route in background ───────────────────────
        // Non-blocking — driver can use the app while this loads
        _fetchAssignedBus();

        return true;

      } catch (e) {
        debugPrint('[Login] Attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }
        _error = 'CONNECTION_FAILED';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }

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
    // Reset bus to inactive via backend
    try {
      final token = await _tokenService.getAccessToken();
      if (token != null) {
        await http.patch(
          Uri.parse('${ApiConfig.baseUrl}/driver/status'),
          headers: {
            'Content-Type':  'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'status': 'inactive'}),
        ).timeout(const Duration(seconds: 5));
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





