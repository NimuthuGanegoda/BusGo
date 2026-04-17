import '../core/constants/api_constants.dart';
import '../models/rating_model.dart';
import 'api_client.dart';

class RatingService {
  final ApiClient _api;
  RatingService(this._api);

  /// GET /ratings — ratings submitted by the current user
  Future<List<RatingModel>> getMyRatings() async {
    final data = await _api.get(ApiEndpoints.ratings);
    final list = data as List<dynamic>;
    return list
        .map((e) => RatingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /ratings — submit a rating for a completed trip
  Future<RatingModel> submitRating({
    required String tripId,
    required String busId,
    required int stars,
    List<String> tags = const [],
    String comment = '',
  }) async {
    final data = await _api.post(ApiEndpoints.ratings, data: {
      'trip_id': tripId,
      'bus_id':  busId,
      'stars':   stars,
      'tags':    tags,
      'comment': comment,
    });
    return RatingModel.fromJson(data as Map<String, dynamic>);
  }

  /// GET /ratings/bus/:busId — public ratings for a specific bus
  Future<List<RatingModel>> getBusRatings(String busId) async {
    final data = await _api.get(ApiEndpoints.busRatings(busId));
    final list = data as List<dynamic>;
    return list
        .map((e) => RatingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
