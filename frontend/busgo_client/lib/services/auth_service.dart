import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'token_service.dart';

/// Handles all authentication API calls and token lifecycle.
class AuthService {
  final ApiClient _api;
  final TokenService _tokenService;

  AuthService(this._api, this._tokenService);

  /// POST /auth/register
  /// Returns the created [UserModel] and saves tokens.
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String username,
    required String phone,
    required String password,
    String? dateOfBirth,
    String membershipType = 'standard',
  }) async {
    final data = await _api.post(ApiEndpoints.register, data: {
      'full_name': fullName,
      'email': email,
      'username': username,
      'phone': phone,
      'password': password,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      'membership_type': membershipType,
    });

    final map = data as Map<String, dynamic>;
    await _tokenService.saveTokens(
      map['access_token'] as String,
      map['refresh_token'] as String,
    );
    return UserModel.fromJson(map['user'] as Map<String, dynamic>);
  }

  /// POST /auth/login
  /// Returns the authenticated [UserModel] and saves tokens.
  Future<UserModel> login(String email, String password) async {
    final data = await _api.post(ApiEndpoints.login, data: {
      'email': email,
      'password': password,
    });

    final map = data as Map<String, dynamic>;
    await _tokenService.saveTokens(
      map['access_token'] as String,
      map['refresh_token'] as String,
    );
    return UserModel.fromJson(map['user'] as Map<String, dynamic>);
  }

  /// POST /auth/logout — revokes refresh token on server.
  Future<void> logout() async {
    final refreshToken = await _tokenService.getRefreshToken();
    try {
      await _api.post(ApiEndpoints.logout, data: {
        if (refreshToken != null) 'refresh_token': refreshToken,
      });
    } catch (_) {
      // Always clear tokens locally even if server call fails.
    } finally {
      await _tokenService.clearTokens();
    }
  }

  /// GET /users/me — validates the stored token and returns the current user.
  /// Throws [UnauthorizedException] if the token is invalid.
  Future<UserModel> getMe() async {
    final data = await _api.get(ApiEndpoints.me);
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  /// POST /auth/forgot-password/request
  Future<void> requestResetPin(String email) async {
    await _api.post(ApiEndpoints.forgotRequest, data: {'email': email});
  }

  /// POST /auth/forgot-password/verify
  /// Returns the short-lived `reset_token` string.
  Future<String> verifyResetPin(String email, String pin) async {
    final data = await _api.post(ApiEndpoints.forgotVerify, data: {
      'email': email,
      'pin': pin,
    });
    return (data as Map<String, dynamic>)['reset_token'] as String;
  }

  /// POST /auth/forgot-password/reset
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _api.post(ApiEndpoints.forgotReset, data: {
      'reset_token': resetToken,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
  }
}
