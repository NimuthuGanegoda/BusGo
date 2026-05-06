import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'token_service.dart';

class AuthService {
  final ApiClient    _api;
  final TokenService _tokenService;

  AuthService(this._api, this._tokenService);

  Future<String?> register({
    required String fullName,
    required String email,
    required String username,
    required String phone,
    required String password,
    String? dateOfBirth,
    String membershipType = 'standard',
    required String answer1,
    required String answer2,
    required String answer3,
  }) async {
    final data = await _api.post(ApiEndpoints.register, data: {
      'full_name':       fullName,
      'email':           email,
      'username':        username,
      'phone':           phone,
      'password':        password,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      'membership_type': membershipType,
      'answer_1':        answer1,
      'answer_2':        answer2,
      'answer_3':        answer3,
    });
    final map = data as Map<String, dynamic>?;
    if (map != null &&
        map['access_token'] != null &&
        map['refresh_token'] != null) {
      await _tokenService.saveTokens(
        map['access_token']  as String,
        map['refresh_token'] as String,
      );
    }
    return map?['recovery_pin'] as String?;
  }

  Future<String> verifyIdentity({
    required String email,
    required String recoveryPin,
    required String answer1,
    required String answer2,
    required String answer3,
  }) async {
    final data = await _api.post('/auth/forgot-password/verify-identity', data: {
      'email':        email,
      'recovery_pin': recoveryPin,
      'answer_1':     answer1,
      'answer_2':     answer2,
      'answer_3':     answer3,
    });
    return (data as Map<String, dynamic>)['reset_token'] as String;
  }

  Future<UserModel> verifyEmail(String email, String pin) async {
    final data = await _api.post('/auth/verify-email',
        data: {'email': email, 'pin': pin});
    final map = data as Map<String, dynamic>;
    await _tokenService.saveTokens(
      map['access_token']  as String,
      map['refresh_token'] as String,
    );
    return UserModel.fromJson(map['user'] as Map<String, dynamic>);
  }

  Future<void> resendVerificationPin(String email) async {
    await _api.post('/auth/verify-email/resend', data: {'email': email});
  }

  Future<UserModel> login(String email, String password) async {
    final data = await _api.post(ApiEndpoints.login, data: {
      'email':    email,
      'password': password,
    });
    final map = data as Map<String, dynamic>;
    await _tokenService.saveTokens(
      map['access_token']  as String,
      map['refresh_token'] as String,
    );
    return UserModel.fromJson(map['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final refreshToken = await _tokenService.getRefreshToken();
    try {
      await _api.post(ApiEndpoints.logout, data: {
        if (refreshToken != null) 'refresh_token': refreshToken,
      });
    } catch (_) {
    } finally {
      await _tokenService.clearTokens();
    }
  }

  Future<UserModel> getMe() async {
    final data = await _api.get(ApiEndpoints.me);
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> requestResetPin(String email) async {
    await _api.post(ApiEndpoints.forgotRequest, data: {'email': email});
  }

  Future<String> verifyResetPin(String email, String pin) async {
    final data = await _api.post(ApiEndpoints.forgotVerify, data: {
      'email': email,
      'pin':   pin,
    });
    return (data as Map<String, dynamic>)['reset_token'] as String;
  }

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _api.post(ApiEndpoints.forgotReset, data: {
      'reset_token':      resetToken,
      'new_password':     newPassword,
      'confirm_password': confirmPassword,
    });
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.post('/auth/change-password', data: {
        'current_password': currentPassword,
        'new_password':     newPassword,
        'confirm_password': newPassword,
      });
      return true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('incorrect') || msg.contains('invalid') ||
          msg.contains('wrong') || msg.contains('401')) {
        return false;
      }
      rethrow;
    }
  }
}