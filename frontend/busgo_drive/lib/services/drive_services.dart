import 'api_client.dart';

// ── Auth Service ──────────────────────────────────────────────────────────────
class DriveAuthService {
  final DriveApiClient _api;
  final DriveTokenService _tokens;
  DriveAuthService(this._api, this._tokens);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _api.post(DriveEndpoints.login,
        data: {'email': email, 'password': password});
    final map = data as Map<String, dynamic>;

    // Verify the user has driver role
    final user = map['user'] as Map<String, dynamic>;
    if (user['role'] != 'driver') {
      throw Exception('This app is for drivers only. Please use BUSGO Client.');
    }

    await _tokens.save(
      map['access_token'] as String,
      map['refresh_token'] as String,
    );
    return user;
  }

  Future<Map<String, dynamic>> getMe() async {
    final data = await _api.get(DriveEndpoints.me);
    return data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    final refresh = await _tokens.getRefresh();
    try {
      await _api.post(DriveEndpoints.logout,
          data: if (refresh != null) {'refresh_token': refresh} else {});
    } catch (_) {}
    await _tokens.clear();
  }

  Future<void> requestResetPin(String email) =>
      _api.post(DriveEndpoints.forgotRequest, data: {'email': email});

  Future<String> verifyPin(String email, String pin) async {
    final d = await _api.post(DriveEndpoints.forgotVerify,
        data: {'email': email, 'pin': pin});
    return (d as Map<String, dynamic>)['reset_token'] as String;
  }

  Future<void> resetPassword(String token, String newPw, String confirm) =>
      _api.post(DriveEndpoints.forgotReset, data: {
        'reset_token':      token,
        'new_password':     newPw,
        'confirm_password': confirm,
      });
}

// ── Driver Service ────────────────────────────────────────────────────────────
class DriveDriverService {
  final DriveApiClient _api;
  DriveDriverService(this._api);

  Future<Map<String, dynamic>?> getMyBus() async {
    final data = await _api.get(DriveEndpoints.myBus);
    return data as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> getMyRating() async {
    final data = await _api.get(DriveEndpoints.myRating);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getCurrentTrip() async {
    final data = await _api.get(DriveEndpoints.currentTrip);
    return data as Map<String, dynamic>?;
  }

  /// Update GPS location — called by background geolocation plugin
  Future<void> updateLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speedKmh,
  }) async {
    await _api.patch(DriveEndpoints.location, data: {
      'lat':      lat,
      'lng':      lng,
      if (heading  != null) 'heading':   heading,
      if (speedKmh != null) 'speed_kmh': speedKmh,
    });
  }

  /// Update crowd level — called when driver taps the crowd button
  Future<void> updateCrowdLevel(String level) async {
    await _api.patch(DriveEndpoints.crowd, data: {'crowd_level': level});
  }
}

// ── Emergency Service ─────────────────────────────────────────────────────────
class DriveEmergencyService {
  final DriveApiClient _api;
  DriveEmergencyService(this._api);

  Future<Map<String, dynamic>> sendAlert({
    required String alertType,
    String? description,
    double? latitude,
    double? longitude,
    String? busId,
  }) async {
    final data = await _api.post(DriveEndpoints.emergency, data: {
      'alert_type':  alertType,
      if (description != null) 'description': description,
      if (latitude    != null) 'latitude':    latitude,
      if (longitude   != null) 'longitude':   longitude,
      if (busId       != null) 'bus_id':      busId,
    });
    return data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyAlerts() async {
    final data = await _api.get(DriveEndpoints.emergency);
    return (data as List).cast<Map<String, dynamic>>();
  }
}

// ── Notification Service ──────────────────────────────────────────────────────
class DriveNotificationService {
  final DriveApiClient _api;
  DriveNotificationService(this._api);

  Future<List<Map<String, dynamic>>> getNotifications({int page = 1}) async {
    final data = await _api.get(DriveEndpoints.notifications,
        params: {'page': page, 'page_size': 20});
    final list = data is List ? data : (data as Map)['notifications'] ?? [];
    return (list as List).cast<Map<String, dynamic>>();
  }

  Future<void> markAllRead() => _api.patch(DriveEndpoints.readAll);
  Future<void> markRead(String id) => _api.patch(DriveEndpoints.readOne(id));
}
