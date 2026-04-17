import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/mock_data_service.dart';

class RouteProvider extends ChangeNotifier {
  List<BusRoute> _routes = [];
  BusRoute? _selectedRoute;
  bool _isLoading = false;

  List<BusRoute> get routes          => _routes;
  List<BusRoute> get assignedRoutes  => _routes.where((r) => r.isAssigned).toList();
  List<BusRoute> get availableRoutes => _routes.where((r) => !r.isAssigned).toList();
  BusRoute? get selectedRoute        => _selectedRoute;
  bool get isLoading                 => _isLoading;

  Future<void> loadRoutes() async {
    _isLoading = true; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));
    _routes = MockDataService.routes;
    _isLoading = false; notifyListeners();
  }

  void selectRoute(BusRoute route) { _selectedRoute = route; notifyListeners(); }
  void clearSelection()            { _selectedRoute = null;  notifyListeners(); }
}
