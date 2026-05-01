import 'api_service.dart';
import 'token_service.dart';

class AuthService {
  final ApiService   _api;
  final TokenService _tokens;

  AuthService(this._api, this._tokens);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final d = await _api.post('/auth/login',
        data: {'email': email, 'password': password});
    final data = d as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    if (user['role'] != 'driver') {
      throw Exception('This app is for drivers only.');
    }
    await _tokens.save(
        data['access_token']  as String,
        data['refresh_token'] as String);
    return user;
  }

  Future<void> logout() async {
    try {
      final ref = await _tokens.getRefresh();
      if (ref != null) {
        await _api.post('/auth/logout', data: {'refresh_token': ref});
      }
    } catch (_) {}
    await _tokens.clear();
  }
}







