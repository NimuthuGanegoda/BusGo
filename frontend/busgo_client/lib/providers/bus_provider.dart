import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/stop_model.dart';
import '../services/bus_service.dart';

class BusProvider extends ChangeNotifier {
  final BusService _busService;

  List<BusModel> _nearbyBuses = [];
  List<StopModel> _nearbyStops = [];
  List<BusRoute> _allRoutes = [];
  List<BusRoute> _searchResults = [];
  BusModel? _selectedBus;
  bool _isLoading = false;
  String _searchQuery = '';
  String? _errorMessage;

  RealtimeChannel? _locationChannel;

  BusProvider(this._busService);

  List<BusModel> get nearbyBuses => _nearbyBuses;
  List<StopModel> get nearbyStops => _nearbyStops;
  List<BusRoute> get allRoutes => _allRoutes;
  List<BusRoute> get searchResults => _searchResults;
  BusModel? get selectedBus => _selectedBus;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> loadNearbyBuses(double lat, double lng,
      {double radius = 20.0}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _nearbyBuses = await _busService.getNearbyBuses(lat, lng, radius: radius);
      if (_selectedBus == null && _nearbyBuses.isNotEmpty) {
        _selectedBus = _nearbyBuses.first;
      }
    } on AppException catch (e) {
      _errorMessage = ErrorHandler.userMessage(e);
    } catch (e) {
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNearbyStops(double lat, double lng) async {
    try {
      _nearbyStops = await _busService.getNearbyStops(lat, lng);
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
    } catch (e) {
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
    }
  }

  Future<void> loadAllRoutes() async {
    try {
      _allRoutes = await _busService.getAllRoutes();
      _searchResults = List.from(_allRoutes);
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
    } catch (e) {
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
    }
  }

  Future<void> loadAll(double lat, double lng, {double radius = 20.0}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.wait([
      loadNearbyBuses(lat, lng, radius: radius),
      loadNearbyStops(lat, lng),
      loadAllRoutes(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  Future<void> searchByDestination(String query) async {
    _searchQuery = query;
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      _searchResults = List.from(_allRoutes);
      notifyListeners();
      return;
    }

    try {
      _searchResults = await _busService.searchRoutes(query);
    } catch (_) {
      _searchResults = _allRoutes
          .where((r) =>
              r.to.toLowerCase().contains(q) ||
              r.from.toLowerCase().contains(q) ||
              r.routeNumber.toLowerCase().contains(q))
          .toList();
    }
    notifyListeners();
  }

  List<String> getDestinationSuggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final destinations = <String>{};
    for (final r in _allRoutes) {
      if (r.from.toLowerCase().contains(q)) destinations.add(r.from);
      if (r.to.toLowerCase().contains(q)) destinations.add(r.to);
    }
    return destinations.toList();
  }

  // ── Selection ───────────────────────────────────────────────────────────────

  void selectBus(BusModel bus) {
    _selectedBus = bus;
    notifyListeners();
  }

  void clearSelection() {
    _selectedBus = null;
    notifyListeners();
  }

  // ── Supabase Realtime — live bus location updates ───────────────────────────

  void subscribeToLiveLocations() {
    _locationChannel = Supabase.instance.client
        .channel(AppConfig.busLocationChannel)
        .onBroadcast(
          event: AppConfig.busLocationEvent,
          callback: (payload) {
            _applyLocationUpdate(payload);
          },
        )
        .subscribe();
  }

  void unsubscribeFromLiveLocations() {
    _locationChannel?.unsubscribe();
    _locationChannel = null;
  }

  void _applyLocationUpdate(Map<String, dynamic> payload) {
    final busId = payload['bus_id'] as String?;
    if (busId == null) return;

    final lat     = (payload['latitude']  as num?)?.toDouble();
    final lng     = (payload['longitude'] as num?)?.toDouble();
    final heading = (payload['heading']   as num?)?.toDouble();
    final speed   = (payload['speed_kmh'] as num?)?.toDouble();

    bool changed = false;

    _nearbyBuses = _nearbyBuses.map((bus) {
      if ((bus.busId ?? bus.stopId) == busId) {
        changed = true;
        return bus.copyWithLocation(
          lat:      lat ?? bus.currentLat ?? 0,
          lng:      lng ?? bus.currentLng ?? 0,
          heading:  heading,
          speedKmh: speed,
        );
      }
      return bus;
    }).toList().cast<BusModel>();

    if (_selectedBus != null &&
        (_selectedBus!.busId ?? _selectedBus!.stopId) == busId) {
      _selectedBus = _selectedBus!.copyWithLocation(
        lat:      lat ?? _selectedBus!.currentLat ?? 0,
        lng:      lng ?? _selectedBus!.currentLng ?? 0,
        heading:  heading,
        speedKmh: speed,
      );
    }

    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeFromLiveLocations();
    super.dispose();
  }
}