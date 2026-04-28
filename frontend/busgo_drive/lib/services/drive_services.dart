import 'api_service.dart';
import 'token_service.dart';

class DriveService {
  final ApiService _api;

  DriveService(this._api);

  Future<Map<String, dynamic>> getProfile() async {
    final data = await _api.get('/users/me');
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyTrips() async {
    final data = await _api.get('/trips');
    return data as List<dynamic>;
  }

  Future<void> updateLocation(double lat, double lng, String busId) async {
    await _api.patch('/buses/$busId/location',
        data: {'latitude': lat, 'longitude': lng});
  }
}



