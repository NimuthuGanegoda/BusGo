import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/stop_model.dart';
import '../services/bus_service.dart';
import '../services/notification_service.dart';

class BusProvider extends ChangeNotifier {
  final BusService _busService;

  List<BusModel>  _nearbyBuses   = [];
  List<StopModel> _nearbyStops   = [];
  List<BusRoute>  _allRoutes     = [];
  List<BusRoute>  _searchResults = [];
  BusModel?       _selectedBus;
  bool            _isLoading     = false;
  String          _searchQuery   = '';
  String?         _errorMessage;

  // ── Stop-based search state ─────────────────────────────────────────────
  List<StopModel>             _allStops        = [];
  List<StopModel>             _stopMatches     = [];
  Map<String, List<BusRoute>> _routesViaStop   = {};
  bool                        _loadingStopRoutes = false;

  // ── Stop arrival notification state ──────────────────────────────────────
  // Set these when the passenger selects a route to watch.
  StopModel?  _watchStartStop;
  StopModel?  _watchEndStop;
  String?     _watchRouteNumber; // e.g. "138" — shown in notification
  bool        _startNotified = false; // prevent repeated notifications
  bool        _endNotified   = false;

  static const double _notifyThresholdMetres = 25.0; // 25 m for home testing

  RealtimeChannel? _locationChannel;

  BusProvider(this._busService);

  List<BusModel>              get nearbyBuses      => _nearbyBuses;
  List<StopModel>             get nearbyStops      => _nearbyStops;
  List<BusRoute>              get allRoutes        => _allRoutes;
  List<BusRoute>              get searchResults    => _searchResults;
  BusModel?                   get selectedBus      => _selectedBus;
  bool                        get isLoading        => _isLoading;
  String                      get searchQuery      => _searchQuery;
  String?                     get errorMessage     => _errorMessage;
  List<StopModel>             get allStops         => _allStops;
  List<StopModel>             get stopMatches      => _stopMatches;
  Map<String, List<BusRoute>> get routesViaStop    => _routesViaStop;
  bool                        get loadingStopRoutes => _loadingStopRoutes;
  StopModel?                  get watchStartStop   => _watchStartStop;
  StopModel?                  get watchEndStop     => _watchEndStop;

  // ── Set which stops to watch ──────────────────────────────────────────────
  /// Call this when the passenger taps a route to track.
  /// [startStop] = nearest stop to passenger (boarding)
  /// [endStop]   = stop nearest to their destination (alighting)
  void setWatchedStops({
    required StopModel startStop,
    required StopModel endStop,
    required String    routeNumber,
  }) {
    _watchStartStop  = startStop;
    _watchEndStop    = endStop;
    _watchRouteNumber = routeNumber;
    _startNotified   = false;
    _endNotified     = false;
    debugPrint('[BusProvider] Watching stops: '
        'START=${startStop.name}, END=${endStop.name}, Route=$routeNumber');
    notifyListeners();
  }

  void clearWatchedStops() {
    _watchStartStop   = null;
    _watchEndStop     = null;
    _watchRouteNumber = null;
    _startNotified    = false;
    _endNotified      = false;
    notifyListeners();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

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

      // ── Check arrival notifications via polling ──────────────────────────
      for (final bus in _nearbyBuses) {
        final busLat = bus.currentLat;
        final busLng = bus.currentLng;
        if (busLat != null && busLng != null) {
          _checkArrivalNotifications(busLat, busLng);
        }
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
      _allRoutes     = await _busService.getAllRoutes();
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

  Future<void> loadAllStops() async {
    try {
      final res = await Supabase.instance.client
          .from('bus_stops')
          .select('id, stop_name, latitude, longitude')
          .order('stop_name');

      _allStops = (res as List).map((s) {
        final json = s as Map<String, dynamic>;
        return StopModel(
          id:        json['id']        as String,
          stopId:    json['id']        as String,
          name:      json['stop_name'] as String? ?? '',
          latitude:  (json['latitude']  as num?)?.toDouble(),
          longitude: (json['longitude'] as num?)?.toDouble(),
          distance:  0,
          routes:    [],
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[BusProvider] loadAllStops error: $e');
    }
  }

  Future<void> loadAll(double lat, double lng, {double radius = 20.0}) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    await Future.wait([
      loadNearbyBuses(lat, lng, radius: radius),
      loadNearbyStops(lat, lng),
      loadAllRoutes(),
      loadAllStops(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> searchByDestination(String query) async {
    _searchQuery = query;
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      _searchResults = List.from(_allRoutes);
      _stopMatches   = [];
      _routesViaStop = {};
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

    _stopMatches = _allStops
        .where((s) => s.name.toLowerCase().contains(q))
        .take(10)
        .toList();

    _loadingStopRoutes = _stopMatches.isNotEmpty;
    notifyListeners();

    for (final stop in _stopMatches) {
      final sid = stop.id ?? stop.stopId;
      if (sid.isEmpty) continue;
      if (!_routesViaStop.containsKey(sid)) {
        await _fetchRoutesViaStop(sid);
      }
    }

    _loadingStopRoutes = false;
    notifyListeners();
  }

  Future<void> _fetchRoutesViaStop(String stopId) async {
    try {
      final res = await Supabase.instance.client
          .from('bus_stop_routes')
          .select('''
            stop_order,
            bus_routes (
              id, route_number, route_name,
              origin, destination, color, is_active
            )
          ''')
          .eq('stop_id', stopId);

      final routes = <BusRoute>[];
      for (final item in (res as List)) {
        final routeData = item['bus_routes'];
        if (routeData != null && routeData is Map<String, dynamic>) {
          routes.add(BusRoute.fromJson(routeData));
        }
      }
      _routesViaStop[stopId] = routes;
      notifyListeners();
    } catch (e) {
      debugPrint('[BusProvider] fetchRoutesViaStop error: $e');
      _routesViaStop[stopId] = [];
    }
  }

  List<String> getDestinationSuggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final suggestions = <String>{};

    for (final r in _allRoutes) {
      if (r.from.toLowerCase().contains(q)) suggestions.add(r.from);
      if (r.to.toLowerCase().contains(q)) suggestions.add(r.to);
    }
    for (final s in _allStops) {
      if (s.name.toLowerCase().contains(q)) suggestions.add(s.name);
    }

    return suggestions.take(8).toList();
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void selectBus(BusModel bus) {
    _selectedBus = bus;
    notifyListeners();
  }

  void clearSelection() {
    _selectedBus = null;
    notifyListeners();
  }

  // ── Supabase Realtime — live bus location + arrival notifications ──────────

  void subscribeToLiveLocations() {
    _locationChannel = Supabase.instance.client
        .channel(AppConfig.busLocationChannel)
        .onBroadcast(
          event:    AppConfig.busLocationEvent,
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
    final busId  = payload['bus_id']    as String?;
    final busLat = (payload['lat']  as num?)?.toDouble();
    final busLng = (payload['lng']  as num?)?.toDouble();

    if (busId == null || busLat == null || busLng == null) return;

    // ── 1. Update bus position in lists ────────────────────────────────────
    final heading = (payload['heading']   as num?)?.toDouble();
    final speed   = (payload['speed_kmh'] as num?)?.toDouble();
    bool changed  = false;

    _nearbyBuses = _nearbyBuses.map((bus) {
      if ((bus.busId ?? bus.stopId) == busId) {
        changed = true;
        return bus.copyWithLocation(
          lat:      busLat,
          lng:      busLng,
          heading:  heading,
          speedKmh: speed,
        );
      }
      return bus;
    }).toList().cast<BusModel>();

    if (_selectedBus != null &&
        (_selectedBus!.busId ?? _selectedBus!.stopId) == busId) {
      _selectedBus = _selectedBus!.copyWithLocation(
        lat:      busLat,
        lng:      busLng,
        heading:  heading,
        speedKmh: speed,
      );
    }

    // ── 2. Check proximity to watched stops ────────────────────────────────
    _checkArrivalNotifications(busLat, busLng);

    if (changed) notifyListeners();
  }

  void _checkArrivalNotifications(double busLat, double busLng) {
    final routeNum = _watchRouteNumber ?? '?';

    // ── Start stop ─────────────────────────────────────────────────────────
    if (!_startNotified && _watchStartStop != null) {
      final sLat = _watchStartStop!.latitude;
      final sLng = _watchStartStop!.longitude;
      if (sLat != null && sLng != null) {
        final dist = NotificationService.distanceMetres(
            busLat, busLng, sLat, sLng);
        debugPrint('[BusProvider] Bus → START stop: ${dist.toStringAsFixed(1)} m');
        if (dist <= _notifyThresholdMetres) {
          _startNotified = true;
          NotificationService.instance.notifyBusArrivingAtStart(
            _watchStartStop!.name,
            routeNum,
          );
        }
      }
    }

    // ── End stop ───────────────────────────────────────────────────────────
    if (!_endNotified && _watchEndStop != null) {
      final eLat = _watchEndStop!.latitude;
      final eLng = _watchEndStop!.longitude;
      if (eLat != null && eLng != null) {
        final dist = NotificationService.distanceMetres(
            busLat, busLng, eLat, eLng);
        debugPrint('[BusProvider] Bus → END stop: ${dist.toStringAsFixed(1)} m');
        if (dist <= _notifyThresholdMetres) {
          _endNotified = true;
          NotificationService.instance.notifyBusArrivingAtEnd(
            _watchEndStop!.name,
            routeNum,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    unsubscribeFromLiveLocations();
    super.dispose();
  }
}









