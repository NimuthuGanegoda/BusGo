import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/helpers.dart';
import '../models/route_model.dart';
import '../models/trip_model.dart';
import '../services/location_service.dart';

class TripProvider extends ChangeNotifier {
  Trip?      _currentTrip;
  BusRoute?  _currentRoute;
  int        _currentStopIndex = 0;
  TripStatus _status           = TripStatus.idle;
  Trip?      _lastCompletedTrip;

  LatLng       _currentLocation  = const LatLng(6.9271, 79.8612);
  double       _currentSpeed     = 0;
  double?      _currentHeading;
  List<LatLng> _traveledPath     = [];
  bool         _gpsReady         = false;
  String?      _gpsError;

  // ── Real passenger count via Supabase Realtime ────────────────────────────
  int              _currentPassengers = 0;
  RealtimeChannel? _passengerChannel;
  String?          _trackedBusId;

  StreamSubscription<Position>? _positionStream;
  final LocationService _locationService = LocationService();

  // ── Getters ───────────────────────────────────────────────────────────────
  Trip?        get currentTrip        => _currentTrip;
  BusRoute?    get currentRoute       => _currentRoute;
  int          get currentStopIndex   => _currentStopIndex;
  TripStatus   get status             => _status;
  Trip?        get lastCompletedTrip  => _lastCompletedTrip;
  LatLng       get currentLocation    => _currentLocation;
  double       get currentSpeed       => _currentSpeed;
  List<LatLng> get traveledPath       => _traveledPath;
  bool         get gpsReady           => _gpsReady;
  String?      get gpsError           => _gpsError;
  int          get currentPassengers  => _currentPassengers;

  RouteStop? get nextStop {
    if (_currentRoute == null) return null;
    if (_currentStopIndex >= _currentRoute!.stops.length) return null;
    return _currentRoute!.stops[_currentStopIndex];
  }

  int get etaMinutes {
    final remaining = (_currentRoute?.stops.length ?? 0) - _currentStopIndex;
    return (remaining * 8).clamp(0, 999);
  }

  // ── Passenger Realtime tracking ───────────────────────────────────────────

  Future<void> startPassengerTracking(String busId) async {
    if (_trackedBusId == busId) return;
    await stopPassengerTracking();
    _trackedBusId = busId;

    await _refreshPassengerCount(busId);

    _passengerChannel = Supabase.instance.client
        .channel('passenger_count_$busId')
        .onPostgresChanges(
          event:  PostgresChangeEvent.all,
          schema: 'public',
          table:  'trips',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'bus_id',
            value:  busId,
          ),
          callback: (_) async => await _refreshPassengerCount(busId),
        )
        .subscribe();

    debugPrint('[Realtime] Tracking passengers on bus $busId');
  }

  Future<void> _refreshPassengerCount(String busId) async {
    try {
      final res = await Supabase.instance.client
          .from('trips')
          .select('id')
          .eq('bus_id', busId)
          .eq('status', 'ongoing');

      _currentPassengers = (res as List).length;
      notifyListeners();
      debugPrint('[Realtime] Passengers on bus: $_currentPassengers');
    } catch (e) {
      debugPrint('[Realtime] Error refreshing count: $e');
    }
  }

  Future<void> stopPassengerTracking() async {
    if (_passengerChannel != null) {
      await Supabase.instance.client.removeChannel(_passengerChannel!);
      _passengerChannel = null;
      _trackedBusId     = null;
      debugPrint('[Realtime] Stopped passenger tracking');
    }
  }

  Future<void> initPassengerTracking(String driverUserId) async {
    try {
      final res = await Supabase.instance.client
          .from('buses')
          .select('id')
          .eq('driver_user_id', driverUserId)
          .maybeSingle();

      if (res != null && res['id'] != null) {
        await startPassengerTracking(res['id'] as String);
      } else {
        debugPrint('[Realtime] No bus assigned to driver — skipping tracking');
      }
    } catch (e) {
      debugPrint('[Realtime] Error finding bus: $e');
    }
  }

  // ── GPS init ──────────────────────────────────────────────────────────────

  Future<bool> initGps() async {
    _gpsError = null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _gpsError = 'Location services are disabled. Please enable GPS.';
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _gpsError = 'Location permission denied.';
        notifyListeners();
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _gpsError = 'Location permission permanently denied. Enable in device settings.';
      notifyListeners();
      return false;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
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
      accuracy:       LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
      _applyPosition(pos);

      // Send location whenever GPS is ready
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
      final dist = const Distance().as(
          LengthUnit.Kilometer, prev, newLocation);
      _currentTrip = _currentTrip!.copyWith(
        distanceCovered: _currentTrip!.distanceCovered + dist,
      );
    }

    notifyListeners();
  }

  // ── Stop GPS stream ───────────────────────────────────────────────────────
  void stopGpsStream() {
    _positionStream?.cancel();
    _positionStream = null;
    _gpsReady = false;
    notifyListeners();
    debugPrint('[GPS] Stream stopped');
  }

  // ── Trip lifecycle ────────────────────────────────────────────────────────

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
      currentPassengers:
          (_currentTrip!.currentPassengers + boarded - alighted).clamp(0, 999),
    );
    notifyListeners();
  }

  void departFromStop() {
    if (_currentTrip == null || _currentRoute == null) return;
    _currentStopIndex++;
    if (_currentStopIndex >= _currentRoute!.stops.length) {
      endTrip();
      return;
    }
    _status = TripStatus.active;
    notifyListeners();
  }

  void endTrip() {
    _status = TripStatus.completed;
    if (_currentTrip != null) {
      _lastCompletedTrip = _currentTrip!.copyWith(
        status:          TripStatus.completed,
        endTime:         DateTime.now(),
        distanceCovered: _currentTrip!.distanceCovered,
        avgSpeed:        _currentSpeed,
        stopsCompleted:  _currentRoute?.stops.length ?? 0,
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