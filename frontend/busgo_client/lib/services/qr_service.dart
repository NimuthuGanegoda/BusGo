import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class QrService {
  final ApiClient _api;
  QrService(this._api);

  /// GET /qr/my-card — returns the current user's QR card data.
  /// The backend regenerates the token if it is expired.
  Future<UserModel> getMyQrCard() async {
    final data = await _api.get(ApiEndpoints.qrCard);
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  /// POST /qr/scan-exit — conductor scans passenger QR to alight them.
  /// [token] is the qr_token UUID from the passenger's card.
  Future<Map<String, dynamic>> scanExit(String token) async {
    final data = await _api.post(ApiEndpoints.qrScanExit, data: {'token': token});
    return data as Map<String, dynamic>;
  }
}
