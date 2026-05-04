import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/drive_services.dart';

class DriveAuthProvider extends ChangeNotifier {
  final DriveAuthService _auth;
  final DriveTokenService _tokens;

  Map<String, dynamic>? _driver;
  bool _isLoading = false;
  String? _error;

  // Forgot-password flow
  int    _fpStep  = 0;
  String _fpEmail = '';
  String _fpToken = '';

  DriveAuthProvider(this._auth, this._tokens);

  Map<String, dynamic>? get driver     => _driver;
  bool                  get isLoggedIn => _driver != null;
  bool                  get isLoading  => _isLoading;
  String?               get error      => _error;
  int                   get fpStep     => _fpStep;

  void clearError() { _error = null; notifyListeners(); }

  /// Restore session on app start
  Future<void> checkSession() async {
    final hasSession = await _tokens.hasSession();
    if (!hasSession) { notifyListeners(); return; }
    try {
      _driver = await _auth.getMe();
    } catch (_) {
      await _tokens.clear();
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      _driver    = await _auth.login(email, password);
      _isLoading = false; notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners(); return false;
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    _driver = null; _error = null;
    notifyListeners();
  }

  Future<bool> sendResetPin(String email) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      await _auth.requestResetPin(email);
      _fpEmail = email; _fpStep = 1;
      _isLoading = false; notifyListeners(); return true;
    } catch (e) {
      _isLoading = false; _error = e.toString();
      notifyListeners(); return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      _fpToken = await _auth.verifyPin(_fpEmail, pin);
      _fpStep  = 2; _isLoading = false; notifyListeners(); return true;
    } catch (e) {
      _isLoading = false; _error = e.toString();
      notifyListeners(); return false;
    }
  }

  Future<bool> resetPassword(String newPw, String confirm) async {
    _isLoading = true; _error = null; notifyListeners();
    if (newPw.length < 8) {
      _isLoading = false; _error = 'Password must be at least 8 characters';
      notifyListeners(); return false;
    }
    if (newPw != confirm) {
      _isLoading = false; _error = 'Passwords do not match';
      notifyListeners(); return false;
    }
    try {
      await _auth.resetPassword(_fpToken, newPw, confirm);
      _fpStep = 0; _fpEmail = ''; _fpToken = '';
      _isLoading = false; notifyListeners(); return true;
    } catch (e) {
      _isLoading = false; _error = e.toString();
      notifyListeners(); return false;
    }
  }
}

class DriveDriverProvider extends ChangeNotifier {
  final DriveDriverService _service;

  Map<String, dynamic>? _bus;
  Map<String, dynamic>? _rating;
  Map<String, dynamic>? _currentTrip;
  bool _isLoading = false;

  DriveDriverProvider(this._service);

  Map<String, dynamic>? get bus         => _bus;
  Map<String, dynamic>? get rating      => _rating;
  Map<String, dynamic>? get currentTrip => _currentTrip;
  bool                  get isLoading   => _isLoading;

  int get passengerCount {
    final trips = _currentTrip?['trips'] as List? ?? [];
    return trips.length;
  }

  String get crowdLevel {
    if (passengerCount == 0) return 'low';
    final capacity = 50; // Default bus capacity
    final ratio = passengerCount / capacity;
    if (ratio >= 1.0) return 'full';
    if (ratio >= 0.75) return 'high';
    if (ratio >= 0.4)  return 'medium';
    return 'low';
  }

  Future<void> loadAll() async {
    _isLoading = true; notifyListeners();
    try {
      await Future.wait([fetchBus(), fetchRating(), fetchCurrentTrip()]);
    } catch (_) {}
    _isLoading = false; notifyListeners();
  }

  Future<void> fetchBus() async {
    _bus = await _service.getMyBus();
    notifyListeners();
  }

  Future<void> fetchRating() async {
    _rating = await _service.getMyRating();
    notifyListeners();
  }

  Future<void> fetchCurrentTrip() async {
    _currentTrip = await _service.getCurrentTrip();
    notifyListeners();
  }

  Future<void> updateLocation(double lat, double lng, {double? heading, double? speed}) async {
    await _service.updateLocation(lat: lat, lng: lng, heading: heading, speedKmh: speed);
  }

  Future<void> updateCrowd(String level) async {
    await _service.updateCrowdLevel(level);
    if (_bus != null) { _bus!['crowd_level'] = level; notifyListeners(); }
  }
}

class DriveEmergencyProvider extends ChangeNotifier {
  final DriveEmergencyService _service;
  bool _isSending = false;
  String? _lastAlertId;
  String? _error;

  DriveEmergencyProvider(this._service);

  bool    get isSending   => _isSending;
  String? get lastAlertId => _lastAlertId;
  String? get error       => _error;

  Future<bool> sendAlert({
    required String alertType,
    String? description,
    double? lat,
    double? lng,
    String? busId,
  }) async {
    _isSending = true; _error = null; notifyListeners();
    try {
      final result = await _service.sendAlert(
        alertType:   alertType,
        description: description,
        latitude:    lat,
        longitude:   lng,
        busId:       busId,
      );
      _lastAlertId = result['id'] as String?;
      _isSending   = false; notifyListeners(); return true;
    } catch (e) {
      _isSending = false; _error = e.toString();
      notifyListeners(); return false;
    }
  }
}










