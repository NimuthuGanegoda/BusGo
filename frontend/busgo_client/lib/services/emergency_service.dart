import '../core/constants/api_constants.dart';
import '../models/emergency_model.dart';
import 'api_client.dart';

class EmergencyService {
  final ApiClient _api;
  EmergencyService(this._api);

  /// GET /emergency — user's own alert history
  Future<List<EmergencyAlertModel>> getAlerts() async {
    final data = await _api.get(ApiEndpoints.emergency);
    final list = data as List<dynamic>;
    return list
        .map((e) => EmergencyAlertModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /emergency — send a new alert
  Future<EmergencyAlertModel> sendAlert({
    required String alertType,
    String? description,
    double? latitude,
    double? longitude,
    String? busId,
    String? tripId,
  }) async {
    final data = await _api.post(ApiEndpoints.emergency, data: {
      'alert_type':  alertType,
      if (description != null) 'description': description,
      if (latitude    != null) 'latitude':    latitude,
      if (longitude   != null) 'longitude':   longitude,
      if (busId       != null) 'bus_id':      busId,
      if (tripId      != null) 'trip_id':     tripId,
    });
    return EmergencyAlertModel.fromJson(data as Map<String, dynamic>);
  }
}
