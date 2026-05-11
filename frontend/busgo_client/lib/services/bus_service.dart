import '../core/constants/api_constants.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/stop_model.dart';
import 'api_client.dart';

class BusService {
  final ApiClient _api;
  BusService(this._api);

  Future<List<BusModel>> getNearbyBuses(double lat, double lng, {double radius = 20.0}) async {
    final data = await _api.get(ApiEndpoints.nearbyBuses, queryParameters: {
      'lat': lat, 'lng': lng, 'radius': radius,
    });
    return (data as List).map((e) => BusModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BusRoute>> getAllRoutes() async {
    final data = await _api.get(ApiEndpoints.busRoutes);
    return (data as List).map((e) => BusRoute.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BusRoute>> searchRoutes(String query) async {
    final data = await _api.get(ApiEndpoints.routeSearch, queryParameters: {'q': query});
    return (data as List).map((e) => BusRoute.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<StopModel>> getNearbyStops(double lat, double lng, {double radius = 0.5}) async {
    final data = await _api.get(ApiEndpoints.nearbyStops, queryParameters: {
      'lat': lat, 'lng': lng, 'radius': radius,
    });
    return (data as List).map((e) => StopModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<StopModel>> getRouteStops(String routeId) async {
    final data = await _api.get(ApiEndpoints.routeStops(routeId));
    return (data as List).map((e) => StopModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BusModel>> getRouteBuses(String routeId) async {
    final data = await _api.get(ApiEndpoints.routeBuses(routeId));
    return (data as List).map((e) => BusModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getRouteById(String routeId) async {
    final data = await _api.get(ApiEndpoints.routeById(routeId));
    return data as Map<String, dynamic>;
}
}










