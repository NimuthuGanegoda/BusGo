import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const String _kBaseUrlDev  = 'http://10.0.2.2:5000/api';
const String _kBaseUrlProd = 'https://your-api-domain.com/api';
const String _kBaseUrl = kDebugMode ? _kBaseUrlDev : _kBaseUrlProd;

// ── Endpoint paths ────────────────────────────────────────────────────────────
class DriveEndpoints {
  DriveEndpoints._();

  // Auth (shared with passenger app)
  static const login         = '/auth/login';
  static const logout        = '/auth/logout';
  static const refresh       = '/auth/refresh';
  static const forgotRequest = '/auth/forgot-password/request';
  static const forgotVerify  = '/auth/forgot-password/verify';
  static const forgotReset   = '/auth/forgot-password/reset';

  // Driver-specific
  static const me            = '/driver/me';
  static const myBus         = '/driver/bus';
  static const myRating      = '/driver/rating';
  static const currentTrip   = '/driver/trip/current';
  static const location      = '/driver/location';
  static const crowd         = '/driver/crowd';

  // Emergency (shared)
  static const emergency     = '/emergency';

  // Notifications
  static const notifications = '/notifications';
  static const readAll       = '/notifications/read-all';
  static String readOne(String id)    => '/notifications/$id/read';
  static String deleteOne(String id)  => '/notifications/$id';
}

// ── Token Service ─────────────────────────────────────────────────────────────
class DriveTokenService {
  static const _keyAccess  = 'busgo_drive_access';
  static const _keyRefresh = 'busgo_drive_refresh';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> save(String access, String refresh) => Future.wait([
    _storage.write(key: _keyAccess,  value: access),
    _storage.write(key: _keyRefresh, value: refresh),
  ]);

  Future<String?> getAccess()  => _storage.read(key: _keyAccess);
  Future<String?> getRefresh() => _storage.read(key: _keyRefresh);

  Future<void> clear() => Future.wait([
    _storage.delete(key: _keyAccess),
    _storage.delete(key: _keyRefresh),
  ]);

  Future<bool> hasSession() async {
    final t = await getAccess();
    return t != null && t.isNotEmpty;
  }

  Future<String> refreshTokens() async {
    final refresh = await getRefresh();
    if (refresh == null) throw Exception('No refresh token');

    final dio = Dio(BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
    ));
    try {
      final res = await dio.post(DriveEndpoints.refresh,
          data: {'refresh_token': refresh});
      final d = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      await save(d['access_token'] as String, d['refresh_token'] as String);
      return d['access_token'] as String;
    } catch (_) {
      await clear();
      rethrow;
    }
  }
}

// ── API Client ────────────────────────────────────────────────────────────────
class DriveApiClient {
  late final Dio _dio;
  final DriveTokenService tokenService;
  bool _refreshing = false;

  DriveApiClient(this.tokenService) {
    _dio = Dio(BaseOptions(
      baseUrl:        _kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers:        {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (opts, handler) async {
        final token = await tokenService.getAccess();
        if (token != null) opts.headers['Authorization'] = 'Bearer $token';
        handler.next(opts);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401 && err.requestOptions.extra['retried'] != true) {
          if (!_refreshing) {
            _refreshing = true;
            try {
              await tokenService.refreshTokens();
            } catch (_) {
              _refreshing = false;
              await tokenService.clear();
              return handler.reject(err);
            }
            _refreshing = false;
          }
          try {
            final newToken = await tokenService.getAccess();
            final opts = err.requestOptions
              ..headers['Authorization'] = 'Bearer $newToken'
              ..extra['retried'] = true;
            final response = await _dio.fetch(opts);
            return handler.resolve(response);
          } catch (e) { return handler.next(err); }
        }
        handler.next(err);
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: false, requestBody: true,
        responseBody: true, error: true, compact: true,
      ));
    }
  }

  dynamic _unwrap(Response res) {
    final body = res.data;
    return body is Map<String, dynamic> ? (body['data'] ?? body) : body;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    final r = await _dio.get(path, queryParameters: params);
    return _unwrap(r);
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    final r = await _dio.post(path, data: data);
    return _unwrap(r);
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    final r = await _dio.patch(path, data: data);
    return _unwrap(r);
  }
}
