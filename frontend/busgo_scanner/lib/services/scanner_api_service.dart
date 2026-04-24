import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _kBaseUrlDev  = 'http://192.168.126.1:5000/api';
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

  /// Cached route ID from the driver's assigned bus
  String? _driverRouteId;

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
      throw Exception('LOGIN_RESTRICTED');
    }
    await _tokens.save(d['access_token'] as String, d['refresh_token'] as String);

    // Fetch and cache the driver's route ID after login
    await _fetchDriverRouteId();

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
    _driverRouteId = null;
  }

  // ── Driver info ───────────────────────────────────────────────────────────

  /// Fetches the driver's assigned bus to get the route_id
  Future<void> _fetchDriverRouteId() async {
    try {
      final res = await _dio.get('/driver/bus');
      final d = _unwrap(res) as Map<String, dynamic>;
      _driverRouteId = d['route_id'] as String?;
    } catch (e) {
      debugPrint('Failed to fetch driver route: $e');
    }
  }

  // ── Ticket Verification (passenger boards) ────────────────────────────────

  /// POST /payments/verify-scan
  /// [scannedToken] is the UUID decoded from the passenger's QR code.
  /// Returns scan result with ticket status: PAID, CASH, or UNKNOWN
  Future<ScanResult> scanIn(String scannedToken) async {
    // Ensure we have the route ID
    if (_driverRouteId == null) {
      await _fetchDriverRouteId();
    }

    final res = await _dio.post('/payments/verify-scan', data: {
      'qr_token': scannedToken,
      'route_id': _driverRouteId,
    });
    final d = _unwrap(res) as Map<String, dynamic>;
    return ScanResult.fromJson(d);
  }

  // ── QR Scan-Exit (passenger alights) ─────────────────────────────────────

  /// POST /qr/scan-exit
  /// NOTE: Keep this if you still need scan-exit functionality,
  /// otherwise remove it.
  Future<ScanResult> scanExit(String scannedToken) async {
    if (_driverRouteId == null) {
      await _fetchDriverRouteId();
    }

    final res = await _dio.post('/payments/verify-scan', data: {
      'qr_token': scannedToken,
      'route_id': _driverRouteId,
    });
    final d = _unwrap(res) as Map<String, dynamic>;
    return ScanResult.fromJson(d);
  }
}

// ── Data model returned after a scan ─────────────────────────────────────────
class ScanResult {
  final bool   success;
  final String status;       // PAID, CASH, or UNKNOWN
  final String message;
  final String passengerName;
  final String routeName;
  final String boardingStop;
  final String alightingStop;

  const ScanResult({
    required this.success,
    required this.status,
    required this.message,
    required this.passengerName,
    required this.routeName,
    required this.boardingStop,
    required this.alightingStop,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final ticket = json['ticket'] as Map<String, dynamic>? ?? {};
    final status = json['payment_status'] as String? ?? 'UNKNOWN';  // was json['status']

    return ScanResult(
      success:       status == 'PAID',
      status:        status,
      message:       json['message'] as String? ?? 'Scan complete',
      passengerName: ticket['passenger_name'] as String? ?? 'Passenger',
      routeName:     ticket['route_name'] as String? ?? '',
      boardingStop:  ticket['from'] as String? ?? '',
      alightingStop: ticket['to'] as String? ?? '',
    );
  }
}


