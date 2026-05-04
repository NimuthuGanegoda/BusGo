import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../models/rating_model.dart';
import '../models/trip_model.dart';
import '../services/rating_service.dart';
import '../services/trip_service.dart';
import '../services/token_service.dart';
import '../services/api_service.dart';

class TripProvider extends ChangeNotifier {
  final TripService   _tripService;
  final RatingService _ratingService;
  final TokenService  _tokenService = TokenService();

  List<TripModel>   _tripHistory = [];
  List<TripModel>   _recentTrips = [];
  List<RatingModel> _ratings     = [];
  TripModel?        _ongoingTrip;

  int          _selectedRating = 3;
  List<String> _selectedTags   = ['Punctual', 'Safe Driving'];
  String       _ratingComment  = '';

  Timer?    _pollTimer;
  String?   _watchingUserId;
  DateTime? _watchStartTime;

  final Set<String> _shownTripIds = {};

  TripModel? _completedTripForRating;
  TripModel? get completedTripForRating => _completedTripForRating;

  int?    _etaMinutes;
  String? _etaContext;
  bool    _etaLoading = false;
  Timer?  _etaTimer;
  String? _etaBusId;
  String? _etaStopId;
  String? _etaToken;

  bool    _isLoading    = false;
  String? _errorMessage;

  TripProvider(this._tripService, this._ratingService);

  List<TripModel>   get tripHistory    => _tripHistory;
  List<TripModel>   get recentTrips    => _recentTrips;
  List<RatingModel> get ratings        => _ratings;
  TripModel?        get ongoingTrip    => _ongoingTrip;
  int               get selectedRating => _selectedRating;
  List<String>      get selectedTags   => _selectedTags;
  String            get ratingComment  => _ratingComment;
  bool              get isLoading      => _isLoading;
  String?           get errorMessage   => _errorMessage;
  int?              get etaMinutes     => _etaMinutes;
  String?           get etaContext     => _etaContext;
  bool              get etaLoading     => _etaLoading;

  int    get totalTrips => _tripHistory.length;
  double get totalSpent => _tripHistory.fold(0, (sum, t) => sum + t.fare);
  double get averageRating {
    if (_tripHistory.isEmpty) return 0;
    return _tripHistory.fold(0, (sum, t) => sum + t.rating) / _tripHistory.length;
  }

  void startWatchingTrips(String userId) {
    if (_watchingUserId == userId) return;
    stopWatchingTrips();
    _watchingUserId = userId;
    _watchStartTime = DateTime.now().toUtc();
    _checkForCompletedTrip();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 8), (_) => _checkForCompletedTrip());
    debugPrint('[TripPoller] Polling every 15s for user $userId');
  }

  Future<void> _checkForCompletedTrip() async {
    try {
      if (_watchStartTime == null) return;
      final token = await _tokenService.getAccessToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$kBaseUrlDev/trips?status=completed&page=1&page_size=5'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final body     = jsonDecode(response.body) as Map<String, dynamic>;
      final rawData  = body['data'];
      final tripList = rawData is List ? rawData : <dynamic>[];

      for (final raw in tripList) {
        final t           = raw as Map<String, dynamic>;
        final tripId      = t['id'] as String?;
        final alightedStr = t['alighted_at'] as String?;

        if (tripId == null || alightedStr == null) continue;

        final alightedAt = DateTime.tryParse(alightedStr)?.toUtc();
        if (alightedAt == null) continue;
        if (alightedAt.isBefore(_watchStartTime!)) continue;
        if (_shownTripIds.contains(tripId)) continue;
        if (_completedTripForRating?.id == tripId) continue;

        debugPrint('[TripPoller] Found unrated trip: $tripId');

        _completedTripForRating = TripModel(
          id:          tripId,
          busId:       t['bus_id']   as String?,
          routeId:     t['route_id'] as String?,
          tripStatus:  'completed',
          routeNumber: (t['bus_route']?['route_number'] as String?) ?? '---',
          from:        (t['boarding_stop']?['stop_name'] as String?) ?? '',
          to:          (t['alighting_stop']?['stop_name'] as String?) ?? '',
          date:        alightedStr.length >= 10 ? alightedStr.substring(0, 10) : '',
          time:        alightedStr.length >= 16 ? alightedStr.substring(11, 16) : '',
          fare:        (t['fare_lkr'] as num?)?.toDouble() ?? 0,
        );
        notifyListeners();
        break;
      }
    } catch (e) {
      debugPrint('[TripPoller] Error: $e');
    }
  }

  void stopWatchingTrips() {
    _pollTimer?.cancel();
    _pollTimer      = null;
    _watchingUserId = null;
    _watchStartTime = null;
  }

  void clearCompletedTrip() {
    if (_completedTripForRating?.id != null) {
      _shownTripIds.add(_completedTripForRating!.id!);
    }
    _completedTripForRating = null;
    notifyListeners();
  }

  void startEtaPolling({
    required String busId,
    required String stopId,
    required String accessToken,
  }) {
    if (_etaBusId == busId && _etaStopId == stopId) return;
    stopEtaPolling();
    _etaBusId  = busId;
    _etaStopId = stopId;
    _etaToken  = accessToken;
    _fetchEta();
    _etaTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchEta());
  }

  void stopEtaPolling() {
    _etaTimer?.cancel();
    _etaTimer   = null;
    _etaBusId   = null;
    _etaStopId  = null;
    _etaToken   = null;
    _etaMinutes = null;
    _etaContext = null;
    _etaLoading = false;
    notifyListeners();
  }

  Future<void> _fetchEta() async {
    if (_etaBusId == null || _etaStopId == null || _etaToken == null) return;
    _etaLoading = true;
    notifyListeners();
    final result = await ApiService().fetchETA(
      busId: _etaBusId!, stopId: _etaStopId!, accessToken: _etaToken!,
    );
    if (result != null) {
      _etaMinutes = (result['eta_minutes'] as num?)?.toInt();
      _etaContext = result['context'] as String?;
    }
    _etaLoading = false;
    notifyListeners();
  }

  Future<void> loadTripHistory() async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _tripHistory = await _tripService.getTrips(status: 'completed');
      _ongoingTrip = await _findOngoingTrip();
      _recentTrips = _tripHistory.length > 2 ? _tripHistory.sublist(0, 2) : _tripHistory;
    } on AppException catch (e) {
      _errorMessage = ErrorHandler.userMessage(e);
    } catch (e) {
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TripModel?> _findOngoingTrip() async {
    try {
      final ongoing = await _tripService.getTrips(status: 'ongoing');
      return ongoing.isNotEmpty ? ongoing.first : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadRatings() async {
    try {
      _ratings = await _ratingService.getMyRatings();
      notifyListeners();
    } catch (_) {}
  }

  Future<TripModel?> startTrip({
    required String busId,
    required String routeId,
    String? boardingStopId,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final trip = await _tripService.startTrip(
        busId: busId, routeId: routeId, boardingStopId: boardingStopId,
      );
      _ongoingTrip = trip;
      _isLoading   = false;
      notifyListeners();
      return trip;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return null;
    }
  }

  Future<TripModel?> alightTrip({String? alightingStopId, double? fareLkr}) async {
    if (_ongoingTrip?.id == null) return null;
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final trip = await _tripService.alightTrip(
        _ongoingTrip!.id!, alightingStopId: alightingStopId, fareLkr: fareLkr,
      );
      _ongoingTrip = null;
      _tripHistory.insert(0, trip);
      _recentTrips = _tripHistory.length > 2 ? _tripHistory.sublist(0, 2) : _tripHistory;
      _isLoading = false;
      notifyListeners();
      return trip;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return null;
    }
  }

  void setRating(int rating) {
    _selectedRating = rating;
    notifyListeners();
  }

  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    notifyListeners();
  }

  void setComment(String comment) {
    _ratingComment = comment;
  }

  Future<bool> submitRating({required String tripId, required String busId}) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final rating = await _ratingService.submitRating(
        tripId: tripId, busId: busId,
        stars: _selectedRating, tags: List.from(_selectedTags), comment: _ratingComment,
      );
      _ratings.insert(0, rating);
      _selectedRating = 3;
      _selectedTags   = ['Punctual', 'Safe Driving'];
      _ratingComment  = '';
      _isLoading      = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopWatchingTrips();
    stopEtaPolling();
    super.dispose();
  }
}







