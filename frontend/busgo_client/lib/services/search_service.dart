import '../core/constants/api_constants.dart';
import 'api_client.dart';

class SearchService {
  final ApiClient _api;
  SearchService(this._api);

  /// GET /searches/recent — last N searches for the current user
  Future<List<Map<String, dynamic>>> getRecentSearches() async {
    final data = await _api.get(ApiEndpoints.recentSearches);
    final list = data as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  /// POST /searches/recent — save a new search query
  Future<void> saveSearch({
    required String query,
    String? fromLocation,
    String? toLocation,
  }) async {
    await _api.post(ApiEndpoints.recentSearches, data: {
      'query': query,
      if (fromLocation != null) 'from_location': fromLocation,
      if (toLocation   != null) 'to_location':   toLocation,
    });
  }
}
