import '../core/constants/api_constants.dart';
import '../models/trip_model.dart';
import 'api_client.dart';

class TripService {
  final ApiClient _api;
  TripService(this._api);

  /// GET /trips?status=&page=&page_size=
  Future<List<TripModel>> getTrips({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _api.get(ApiEndpoints.trips, queryParameters: {
      if (status != null) 'status': status,
      'page':      page,
      'page_size': pageSize,
    });
    final list = data as List<dynamic>;
    return list.map((e) => TripModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /trips/:id
  Future<TripModel> getTripById(String id) async {
    final data = await _api.get(ApiEndpoints.tripById(id));
    return TripModel.fromJson(data as Map<String, dynamic>);
  }

  /// POST /trips — start a trip (board bus).
  Future<TripModel> startTrip({
    required String busId,
    required String routeId,
    String? boardingStopId,
  }) async {
    final data = await _api.post(ApiEndpoints.trips, data: {
      'bus_id':           busId,
      'route_id':         routeId,
      if (boardingStopId != null) 'boarding_stop_id': boardingStopId,
    });
    return TripModel.fromJson(data as Map<String, dynamic>);
  }

  /// PATCH /trips/:id/alight — end a trip (exit bus).
  Future<TripModel> alightTrip(
    String tripId, {
    String? alightingStopId,
    double? fareLkr,
  }) async {
    final data = await _api.patch(ApiEndpoints.tripAlight(tripId), data: {
      if (alightingStopId != null) 'alighting_stop_id': alightingStopId,
      if (fareLkr != null) 'fare_lkr': fareLkr,
    });
    return TripModel.fromJson(data as Map<String, dynamic>);
  }
}
