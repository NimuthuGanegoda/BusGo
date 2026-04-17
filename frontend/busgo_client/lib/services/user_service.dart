import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _api;
  UserService(this._api);

  /// GET /users/me
  Future<UserModel> getProfile() async {
    final data = await _api.get(ApiEndpoints.me);
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  /// PATCH /users/me
  Future<UserModel> updateProfile(Map<String, dynamic> fields) async {
    final data = await _api.patch(ApiEndpoints.me, data: fields);
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  /// PATCH /users/me/avatar  (multipart/form-data)
  Future<String> uploadAvatar(Uint8List bytes, String fileName, String mimeType) async {
    final data = await _api.uploadFile(
      ApiEndpoints.myAvatar, bytes, fileName, mimeType,
    );
    return (data as Map<String, dynamic>)['avatar_url'] as String;
  }

  /// GET /users/me/preferences
  Future<Map<String, dynamic>> getPreferences() async {
    final data = await _api.get(ApiEndpoints.myPreferences);
    return data as Map<String, dynamic>;
  }

  /// PATCH /users/me/preferences
  Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> prefs) async {
    final data = await _api.patch(ApiEndpoints.myPreferences, data: prefs);
    return data as Map<String, dynamic>;
  }

  /// GET /users/me/stats → { total_trips, total_spent_lkr, average_rating }
  Future<Map<String, dynamic>> getStats() async {
    final data = await _api.get(ApiEndpoints.myStats);
    return data as Map<String, dynamic>;
  }
}
