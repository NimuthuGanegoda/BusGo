import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _kBaseUrlDev  = 'http://192.168.8.101:5000/api';
const String _kBaseUrlProd = 'https://your-api-domain.com/api';
const String _kBaseUrl     = kDebugMode ? _kBaseUrlDev : _kBaseUrlProd;

// ── Token storage ─────────────────────────────────────────────────────────────
class ScannerTokenService {
  static const _kAccess  = 'busgo_scanner_access';
  static const _kRefresh = 'busgo_scanner_refresh';

  final _store = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> save(String access, String refresh) => Future.wait([
    _store.write(key: _kAccess,  value: access),
    _store.write(key: _kRefresh, value: refresh),
  ]);

  Future<String?> getAccess()  => _store.read(key: _kAccess);
  Future<String?> getRefresh() => _store.read(key: _kRefresh);
  Future<bool>    hasSession() async => (await getAccess()) != null;

  Future<void> clear() => Future.wait([
    _store.delete(key: _kAccess),
    _store.delete(key: _kRefresh),
  ]);
}

// ── API client ────────────────────────────────────────────────────────────────
class ScannerApiService {
  late final Dio _dio;
  final ScannerTokenService _tokens;
  bool _refreshing = false;

  ScannerApiService(this._tokens) {
    _dio = Dio(BaseOptions(
      baseUrl:        _kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers:        {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (opts, handler) async {
        final t = await _tokens.getAccess();
        if (t != null) opts.headers['Authorization'] = 'Bearer $t';
        handler.next(opts);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401 && err.requestOptions.extra['retried'] != true) {
          if (!_refreshing) {
            _refreshing = true;
            try {
              final ref = await _tokens.getRefresh();
              if (ref == null) throw Exception('no refresh');
              final res = await Dio(BaseOptions(baseUrl: _kBaseUrl))
                  .post('/auth/refresh', data: {'refresh_token': ref});
              final d = (res.data as Map)['data'] as Map;
              await _tokens.save(d['access_token'] as String, d['refresh_token'] as String);
            } catch (_) {
              _refreshing = false;
              await _tokens.clear();
              return handler.reject(err);
            }
            _refreshing = false;
          }
          try {
            final t    = await _tokens.getAccess();
            final opts = err.requestOptions
              ..headers['Authorization'] = 'Bearer $t'
              ..extra['retried'] = true;
            final res = await _dio.fetch(opts);
            return handler.resolve(res);
          } catch (_) { return handler.next(err); }
        }
        handler.next(err);
      },
    ));
  }

  dynamic _unwrap(Response res) {
    final b = res.data;
    return b is Map<String, dynamic> ? (b['data'] ?? b) : b;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Login as a driver. Saves tokens and returns user map.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login',
        data: {'email': email, 'password': password});
    final d   = _unwrap(res) as Map<String, dynamic>;
    final user = d['user'] as Map<String, dynamic>;
    if (user['role'] != 'driver') {
      throw Exception('Scanner is for drivers only.');
    }
    await _tokens.save(d['access_token'] as String, d['refresh_token'] as String);
    return user;
  }

  Future<void> logout() async {
    final ref = await _tokens.getRefresh();
    try {
      await _dio.post('/auth/logout',
        data: ref != null ? {'refresh_token': ref} : {},
      );
    } catch (_) {}
    await _tokens.clear();
  }

  // ── QR Scan-In (passenger boards) ─────────────────────────────────────────

  /// POST /qr/scan-in
  /// [scannedToken] is the UUID decoded from the passenger's QR code.
  /// Returns { trip_id, passenger: { full_name, membership_type, ... }, message }
  Future<ScanResult> scanIn(String scannedToken) async {
    final res = await _dio.post('/qr/scan-in',
        data: {'scanned_token': scannedToken});
    final d = _unwrap(res) as Map<String, dynamic>;
    return ScanResult.fromJson(d, isBoarding: true);
  }

  // ── QR Scan-Exit (passenger alights) ─────────────────────────────────────

  /// POST /qr/scan-exit
  Future<ScanResult> scanExit(String scannedToken) async {
    final res = await _dio.post('/qr/scan-exit',
        data: {'scanned_token': scannedToken});
    final d = _unwrap(res) as Map<String, dynamic>;
    return ScanResult.fromJson(d, isBoarding: false);
  }
}

// ── Data model returned after a scan ─────────────────────────────────────────
class ScanResult {
  final bool   success;
  final bool   isBoarding;
  final String tripId;
  final String passengerName;
  final String membershipType;
  final String message;

  const ScanResult({
    required this.success,
    required this.isBoarding,
    required this.tripId,
    required this.passengerName,
    required this.membershipType,
    required this.message,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json, {required bool isBoarding}) {
    final pax = json['passenger'] as Map<String, dynamic>? ?? {};
    return ScanResult(
      success:        true,
      isBoarding:     isBoarding,
      tripId:         json['trip_id']   as String? ?? '',
      passengerName:  pax['full_name']      as String? ?? 'Passenger',
      membershipType: pax['membership_type'] as String? ?? 'standard',
      message:        json['message']   as String? ?? 'Scan successful',
    );
  }
}
