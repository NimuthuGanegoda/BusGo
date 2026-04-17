import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config/app_config.dart';
import '../core/constants/api_constants.dart';
import '../core/errors/app_exception.dart';

/// Manages JWT access + refresh token storage and automatic token rotation.
/// Uses [FlutterSecureStorage] — tokens are never stored in SharedPreferences.
class TokenService {
  static const _keyAccess  = 'busgo_access_token';
  static const _keyRefresh = 'busgo_refresh_token';

  final FlutterSecureStorage _storage;

  TokenService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await Future.wait([
      _storage.write(key: _keyAccess,  value: accessToken),
      _storage.write(key: _keyRefresh, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken()  => _storage.read(key: _keyAccess);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefresh);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _keyAccess),
      _storage.delete(key: _keyRefresh),
    ]);
  }

  Future<bool> hasSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── Token rotation ────────────────────────────────────────────────────────

  /// Exchange the stored refresh token for a new access + refresh pair.
  /// Saves the new tokens and returns the new access token.
  /// Throws [SessionExpiredException] if the refresh token is invalid/expired.
  Future<String> refreshTokens() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const SessionExpiredException();
    }

    // Use a bare Dio instance (no interceptors) to avoid infinite loops.
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
    ));

    try {
      final response = await dio.post(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );

      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;

      final newAccess  = data['access_token']  as String;
      final newRefresh = data['refresh_token'] as String;

      await saveTokens(newAccess, newRefresh);
      return newAccess;
    } on DioException {
      await clearTokens();
      throw const SessionExpiredException();
    }
  }
}
