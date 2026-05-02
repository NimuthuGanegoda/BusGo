import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/config/api_config.dart';
import '../core/utils/helpers.dart';
import '../models/route_model.dart';
import '../models/trip_model.dart';
import '../services/location_service.dart';
import '../services/token_service.dart';

class TripProvider extends ChangeNotifier {
  Trip?      _currentTrip;
  BusRoute?  _currentRoute;
  int        _currentStopIndex = 0;
  TripStatus _status           = TripStatus.idle;
  Trip?      _lastCompletedTrip;

  LatLng       _currentLocation = const LatLng(6.9271, 79.8612);
  double       _currentSpeed    = 0;
  double?      _currentHeading;
  List<LatLng> _traveledPath    = [];
  bool         _gpsReady        = false;
  String?      _gpsError;

  // ── Passenger count + FR-34 express mode ──────────────────────────────────
  int          _currentPassengers = 0;
  int          _busCapacity       = 50;
  bool         _isExpressMode     = false;
  List<Map<String, dynamic>> _mustStopAt = []; // [{ id, name }]
  String?      _busId;

  Timer? _passengerPollTimer;
  StreamSubscription<Position>? _positionStream;
  final LocationService _locationService = LocationService();
  final TokenService    _tokenService    = TokenService();

  // ── Getters ───────────────────────────────────────────────────────────────
  Trip?        get currentTrip       => _currentTrip;
  BusRoute?    get currentRoute      => _currentRoute;
  int          get currentStopIndex  => _currentStopIndex;
  TripStatus   get status            => _status;
  Trip?        get lastCompletedTrip => _lastCompletedTrip;
  LatLng       get currentLocation   => _currentLocation;
  double       get currentSpeed      => _currentSpeed;
  List<LatLng> get traveledPath      => _traveledPath;
  bool         get gpsReady          => _gpsReady;
  String?      get gpsError          => _gpsError;
  int          get currentPassengers => _currentPassengers;

  // FR-34 getters
  int          get busCapacity      => _busCapacity;
  bool         get isExpressMode    => _isExpressMode;
  String?      get busId            => _busId;
  List<Map<String, dynamic>> get mustStopAt => _mustStopAt;
  int          get mustStopCount    => _mustStopAt.length;

  RouteStop? get nextStop {
    if (_currentRoute == null) return null;
    if (_currentStopIndex >= _currentRoute!.stops.length) return null;
    return _currentRoute!.stops[_currentStopIndex];
  }

  int get etaMinutes {
    final remaining = (_currentRoute?.stops.length ?? 0) - _currentStopIndex;
    return (remaining * 8).clamp(0, 999);
  }

  // ── Passenger count + express mode polling ─────────────────────────────────
  Future<void> initPassengerTracking(String driverUserId) async {
    await _refreshPassengerCount();
    _passengerPollTimer?.cancel();
    _passengerPollTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _refreshPassengerCount());
    debugPrint('[TripProvider] Passenger + express mode polling started');
  }

  Future<void> _refreshPassengerCount() async {
    try {
      final token = await _tokenService.getAccessToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/driver/trip/current'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null) {
          final count        = data['active_passengers'] as int? ?? 0;
          final capacity     = data['bus_capacity']      as int? ?? 50;
          final expressMode  = data['is_express_mode']   as bool? ?? false;
          final busId        = data['bus_id']            as String?;  // ← ADD THIS
          if (busId != null) _busId = busId;
          final rawMustStop  = data['must_stop_at']      as List<dynamic>? ?? [];
          final mustStopList = rawMustStop
              .whereType<Map<String, dynamic>>()
              .toList();

          bool changed = false;
          if (_currentPassengers != count)       { _currentPassengers = count;       changed = true; }
          if (_busCapacity       != capacity)    { _busCapacity       = capacity;    changed = true; }
          if (_isExpressMode     != expressMode) { _isExpressMode     = expressMode; changed = true; }
          if (_mustStopAt.length != mustStopList.length) {
            _mustStopAt = mustStopList;
            changed = true;
          }

          if (changed) {
            notifyListeners();
            if (expressMode) {
              debugPrint('[TripProvider] 🚌 EXPRESS MODE ON — '
                  '$count/$capacity passengers — '
                  '${mustStopList.length} must-stop points');
            } else {
              debugPrint('[TripProvider] Passengers: $count/$capacity');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TripProvider] Passenger poll error: $e');
    }
  }

  Future<void> stopPassengerTracking() async {
    _passengerPollTimer?.cancel();
    _passengerPollTimer = null;
  }

  // ── GPS ────────────────────────────────────────────────────────────────────
  Future<bool> initGps() async {
    _gpsError = null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _gpsError = 'Location services are disabled. Please enable GPS.';
      notifyListeners(); return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _gpsError = 'Location permission denied.'; notifyListeners(); return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _gpsError = 'Location permission permanently denied. Enable in device settings.';
      notifyListeners(); return false;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _applyPosition(pos);
    } catch (_) {}

    _gpsReady = true;
    _startGpsStream();
    notifyListeners();
    return true;
  }

  void _startGpsStream() {
    _positionStream?.cancel();
    const settings = LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 10);

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
      _applyPosition(pos);
      if (_gpsReady) {
        _locationService.updateLocation(
          lat:      pos.latitude,
          lng:      pos.longitude,
          speedKmh: (pos.speed * 3.6).clamp(0, 200),
          heading:  pos.heading >= 0 ? pos.heading : null,
        );
      }
    }, onError: (e) {
      _gpsError = 'GPS error: $e';
      notifyListeners();
    });
  }

  void _applyPosition(Position pos) {
    final newLocation = LatLng(pos.latitude, pos.longitude);
    _currentLocation  = newLocation;
    _currentSpeed     = (pos.speed * 3.6).clamp(0, 200);
    _currentHeading   = pos.heading >= 0 ? pos.heading : null;

    if (_traveledPath.isEmpty) {
      _traveledPath = [newLocation];
    } else {
      _traveledPath = [..._traveledPath, newLocation];
      if (_traveledPath.length > 200) {
        _traveledPath = _traveledPath.sublist(_traveledPath.length - 200);
      }
    }

    if (_currentTrip != null && _traveledPath.length >= 2) {
      final prev = _traveledPath[_traveledPath.length - 2];
      final dist = const Distance().as(LengthUnit.Kilometer, prev, newLocation);
      _currentTrip = _currentTrip!.copyWith(
          distanceCovered: _currentTrip!.distanceCovered + dist);
    }

    notifyListeners();
  }

  void stopGpsStream() {
    _positionStream?.cancel();
    _positionStream = null;
    _gpsReady       = false;
    notifyListeners();
  }

  // ── Trip lifecycle ─────────────────────────────────────────────────────────
  Future<void> startTrip(BusRoute route) async {
    _currentRoute     = route;
    _currentStopIndex = 0;
    _status           = TripStatus.active;
    _traveledPath     = [];

    _currentTrip = Trip(
      id:            'TRP-${DateTime.now().millisecondsSinceEpoch}',
      routeId:       route.id,
      routeNumber:   route.routeNumber,
      routeName:     route.name,
      driverId:      'DRV-REAL',
      startTime:     DateTime.now(),
      totalStops:    route.stops.length,
      totalDistance: route.distanceKm,
    );

    if (!_gpsReady) await initGps();
    notifyListeners();
  }

  void arriveAtStop() {
    if (_currentTrip == null || _currentRoute == null) return;
    _status = TripStatus.atStop;
    notifyListeners();
  }

  void updatePassengers(int boarded, int alighted) {
    if (_currentTrip == null) return;
    _currentTrip = _currentTrip!.copyWith(
      passengersBoarded:  _currentTrip!.passengersBoarded  + boarded,
      passengersAlighted: _currentTrip!.passengersAlighted + alighted,
      currentPassengers:  (_currentTrip!.currentPassengers + boarded - alighted)
          .clamp(0, 999),
    );
    notifyListeners();
  }

  void departFromStop() {
    if (_currentTrip == null || _currentRoute == null) return;
    _currentStopIndex++;
    if (_currentStopIndex >= _currentRoute!.stops.length) {
      endTrip(); return;
    }
    _status = TripStatus.active;
    notifyListeners();
  }

  void endTrip() {
    _status = TripStatus.completed;
    if (_currentTrip != null) {
      _lastCompletedTrip = _currentTrip!.copyWith(
        status:         TripStatus.completed,
        endTime:        DateTime.now(),
        distanceCovered:_currentTrip!.distanceCovered,
        avgSpeed:       _currentSpeed,
        stopsCompleted: _currentRoute?.stops.length ?? 0,
      );
    }
    _currentTrip      = null;
    _currentRoute     = null;
    _currentStopIndex = 0;
    _traveledPath     = [];
    notifyListeners();
  }

  void resetForNewTrip() {
    _lastCompletedTrip = null;
    _status            = TripStatus.idle;
    _traveledPath      = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    stopPassengerTracking();
    super.dispose();
  }
}





