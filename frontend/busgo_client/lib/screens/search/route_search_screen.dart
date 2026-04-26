import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../models/route_model.dart';
import '../../models/stop_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/api_service.dart';

class RouteSearchScreen extends StatefulWidget {
  const RouteSearchScreen({super.key});
  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocus = FocusNode();

  bool _showSuggestions = false;
  List<String> _suggestions = [];

  String? _expandedRouteId;
  List<Map<String, dynamic>> _routeBuses = [];
  bool _loadingBuses = false;

  final Map<String, int?> _busEtas = {};
  final Map<String, bool> _busEtaLoading = {};
  String? _trackingBusId;

  StopModel? _nearestStop;
  double? _userLat;
  double? _userLng;
  bool _locating = true;

  // Auto-refresh timer
  Timer? _stopRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initLocation();
      context.read<TripProvider>().loadTripHistory();
    });
    _destinationController.addListener(_onSearchChanged);
    _destinationFocus.addListener(() {
      setState(() {
        _showSuggestions =
            _destinationFocus.hasFocus && _suggestions.isNotEmpty;
      });
    });

    // Auto-refresh nearest stop every 30 seconds
    _stopRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshNearestStop(),
    );
  }

  @override
  void dispose() {
    _stopRefreshTimer?.cancel();
    _destinationController.removeListener(_onSearchChanged);
    _destinationController.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  // ── Location & nearest stop ──────────────────────────────────────────────

  Future<void> _initLocation() async {
    setState(() => _locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _fallbackLocation();
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _userLat = position.latitude;
      _userLng = position.longitude;
    } catch (e) {
      debugPrint('[Search] Location error: $e');
      _fallbackLocation();
    }

    await _loadAllData();
    setState(() => _locating = false);
  }

  void _fallbackLocation() {
    // Default to Colombo Fort if location unavailable
    _userLat = 6.9344;
    _userLng = 79.8428;
  }

  Future<void> _loadAllData() async {
    final lat = _userLat ?? 6.9344;
    final lng = _userLng ?? 79.8428;

    final busProvider = context.read<BusProvider>();
    await busProvider.loadAll(lat, lng);
    await _refreshNearestStop();
  }

  Future<void> _refreshNearestStop() async {
    if (!mounted) return;
    final lat = _userLat ?? 6.9344;
    final lng = _userLng ?? 79.8428;

    try {
      // Try to get fresh location first
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 5));
      _userLat = position.latitude;
      _userLng = position.longitude;
    } catch (_) {
      // Use last known location
    }

    final busProvider = context.read<BusProvider>();
    await busProvider.loadNearbyStops(_userLat ?? lat, _userLng ?? lng);

    if (busProvider.nearbyStops.isNotEmpty && mounted) {
      setState(() => _nearestStop = busProvider.nearbyStops.first);
    }
  }

  // ── Search logic ─────────────────────────────────────────────────────────

  void _onSearchChanged() {
    final query = _destinationController.text;
    final busProvider = context.read<BusProvider>();
    _suggestions = busProvider.getDestinationSuggestions(query);
    busProvider.searchByDestination(query);
    setState(() {
      _showSuggestions = _destinationFocus.hasFocus && _suggestions.isNotEmpty;
      _expandedRouteId = null;
      _routeBuses = [];
      _busEtas.clear();
    });
  }

  void _selectDestination(String destination) {
    _destinationController.text = destination;
    _destinationFocus.unfocus();
    setState(() => _showSuggestions = false);
    context.read<BusProvider>().searchByDestination(destination);
  }

  void _clearSearch() {
    _destinationController.clear();
    context.read<BusProvider>().searchByDestination('');
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
      _expandedRouteId = null;
      _routeBuses = [];
      _busEtas.clear();
    });
  }

  // ── Route tap → load buses ────────────────────────────────────────────────

  Future<void> _onRouteTapped(BusRoute route) async {
    if (_expandedRouteId == route.id) {
      setState(() {
        _expandedRouteId = null;
        _routeBuses = [];
        _busEtas.clear();
      });
      return;
    }

    setState(() {
      _expandedRouteId = route.id;
      _routeBuses = [];
      _loadingBuses = true;
      _busEtas.clear();
    });

    try {
      final res = await Supabase.instance.client
          .from('buses')
          .select(
              'id, bus_number, driver_name, current_lat, current_lng, speed_kmh, crowd_level, status')
          .eq('route_id', route.id!)
          .eq('status', 'active')
          .not('current_lat', 'is', null)
          .not('current_lng', 'is', null);

      final buses = (res as List).cast<Map<String, dynamic>>();
      setState(() {
        _routeBuses = buses;
        _loadingBuses = false;
      });

      for (final bus in buses) {
        _fetchEtaForBus(bus['id'] as String);
      }
    } catch (e) {
      debugPrint('[Search] Bus fetch error: $e');
      setState(() => _loadingBuses = false);
    }
  }

  Future<void> _fetchEtaForBus(String busId) async {
    final stopId = _nearestStop?.id;
    if (stopId == null) return;

    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;

    setState(() => _busEtaLoading[busId] = true);

    try {
      final result = await ApiService().fetchETA(
        busId: busId,
        stopId: stopId,
        accessToken: token,
      );

      setState(() {
        _busEtas[busId] = (result?['eta_minutes'] as num?)?.toInt();
        _busEtaLoading[busId] = false;
      });
    } catch (e) {
      setState(() {
        _busEtas[busId] = null;
        _busEtaLoading[busId] = false;
      });
    }
  }

  void _onBoardBus(String busId, String busNumber) {
    final busProvider = context.read<BusProvider>();
    final nearestStop = _nearestStop;

    if (nearestStop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No nearby stop detected. Move closer to a bus stop.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _trackingBusId = busId);

    busProvider.setWatchedStops(
      startStop:   nearestStop,
      endStop:     nearestStop,
      routeNumber: busNumber,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('Now tracking Bus $busNumber · You will be notified when it arrives')),
        ]),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  int _localEta(Map<String, dynamic> bus) {
    final busLat = (bus['current_lat'] as num?)?.toDouble();
    final busLng = (bus['current_lng'] as num?)?.toDouble();
    final speed = (bus['speed_kmh'] as num?)?.toDouble() ?? 20.0;

    if (busLat == null || busLng == null) return 0;

    final targetLat = _nearestStop?.latitude ?? _userLat ?? 6.9271;
    final targetLng = _nearestStop?.longitude ?? _userLng ?? 79.8612;

    const R = 6371.0;
    final dLat = (targetLat - busLat) * pi / 180;
    final dLng = (targetLng - busLng) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(busLat * pi / 180) *
            cos(targetLat * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final distKm = 2 * R * asin(sqrt(a));

    return ((distKm / speed) * 60).round().clamp(1, 999);
  }

  // ── Nearest stop distance display ────────────────────────────────────────

  String _stopDistanceText(StopModel stop) {
    if (_userLat == null || _userLng == null) return '';
    final lat = stop.latitude ?? 0;
    final lng = stop.longitude ?? 0;
    if (lat == 0 && lng == 0) return '';

    const R = 6371.0;
    final dLat = (lat - _userLat!) * pi / 180;
    final dLng = (lng - _userLng!) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_userLat! * pi / 180) *
            cos(lat * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final distKm = 2 * R * asin(sqrt(a));

    if (distKm < 1) {
      return '${(distKm * 1000).round()} m away';
    }
    return '${distKm.toStringAsFixed(1)} km away';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: _locating
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.secondary),
                      SizedBox(height: 16),
                      Text('Finding your location...',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showSuggestions) _buildSuggestions(),
                      _buildNearestStopBadge(),
                      const SizedBox(height: 12),
                      _buildNearbyStops(),
                      const SizedBox(height: 8),
                      _buildRecentTrips(),
                      const SizedBox(height: 8),
                      _buildSearchResults(),
                      const SizedBox(height: 8),
                      _buildStopBasedRoutes(),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }

  // ── Nearest stop badge ────────────────────────────────────────────────────

  Widget _buildNearestStopBadge() {
    if (_nearestStop == null) return const SizedBox.shrink();
    final distText = _stopDistanceText(_nearestStop!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.near_me_rounded, size: 16, color: AppColors.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nearestStop!.name,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600),
              ),
              if (distText.isNotEmpty)
                Text(
                  distText,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondary.withOpacity(0.7),
                      fontWeight: FontWeight.w400),
                ),
            ],
          ),
        ),
        // Refresh button
        GestureDetector(
          onTap: _refreshNearestStop,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.refresh_rounded,
                size: 14, color: AppColors.secondary),
          ),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final stopName = _nearestStop?.name ?? 'Detecting location...';
    final distText =
        _nearestStop != null ? _stopDistanceText(_nearestStop!) : '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1A2E), Color(0xFF132F54), Color(0xFF1E5AA8)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_bus_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Find Your Bus',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    SizedBox(height: 2),
                    Text('Search routes, stops & destinations',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400)),
                  ],
                ),
              ]),
              const SizedBox(height: 20),
              _buildSearchCard(stopName, distText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard(String stopName, String distText) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        // FROM row — shows nearest stop
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.my_location_rounded,
                size: 16, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FROM',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1.0)),
                const SizedBox(height: 2),
                Text(
                  stopName,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (distText.isNotEmpty)
                  Text(
                    distText,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.secondary.withOpacity(0.8),
                        fontWeight: FontWeight.w400),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _refreshNearestStop,
            child: Icon(Icons.gps_fixed_rounded,
                size: 16, color: AppColors.secondary.withOpacity(0.7)),
          ),
        ]),

        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(children: [
            Container(width: 1, height: 16, color: AppColors.border),
            const Expanded(
                child: Divider(
                    height: 1, indent: 14, color: Color(0x1AFFFFFF))),
          ]),
        ),

        // TO row — destination search
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_on_rounded,
                size: 16, color: AppColors.danger),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TO',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1.0)),
                SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _destinationController,
                    focusNode: _destinationFocus,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      hintText: 'Where do you want to go?',
                      hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w400),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_destinationController.text.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textMuted),
              ),
            )
          else
            const Icon(Icons.search_rounded,
                size: 18, color: AppColors.textMuted),
        ]),
      ]),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Text('SUGGESTIONS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8)),
        ),
        ..._suggestions.take(5).map((destination) => InkWell(
              onTap: () => _selectDestination(destination),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.place_outlined,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Text(destination,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            )),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ]),
    );
  }

  Widget _buildNearbyStops() {
    return Consumer<BusProvider>(builder: (context, busProvider, _) {
      if (busProvider.nearbyStops.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionHeader('Nearby Stops', Icons.near_me_rounded),
        ...busProvider.nearbyStops.take(3).map((stop) {
          final dist = _stopDistanceText(stop);
          return _buildStopItem(
            icon: Icons.location_on_outlined,
            title: stop.name,
            subtitle: dist.isNotEmpty ? dist : stop.info,
            showArrow: true,
            onTap: () => _selectDestination(stop.name),
          );
        }),
      ]);
    });
  }

  Widget _buildRecentTrips() {
    return Consumer<TripProvider>(builder: (context, tripProvider, _) {
      if (tripProvider.recentTrips.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionHeader('Recent Trips', Icons.history_rounded),
        ...tripProvider.recentTrips.map((trip) => _buildStopItem(
              icon: Icons.schedule_rounded,
              title: trip.from,
              subtitle: 'Route ${trip.routeNumber} · ${trip.date}',
              onTap: () => _selectDestination(trip.from),
            )),
      ]);
    });
  }

  Widget _buildSearchResults() {
    return Consumer<BusProvider>(builder: (context, busProvider, _) {
      final results = busProvider.searchResults;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _buildSectionHeader(
            busProvider.searchQuery.isEmpty
                ? 'Available Routes'
                : 'Search Results',
            Icons.route_rounded,
          ),
          const Spacer(),
          if (results.isNotEmpty)
            Text(
              '${results.length} ${results.length == 1 ? 'route' : 'routes'}',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted.withOpacity(0.7),
                  fontWeight: FontWeight.w500),
            ),
        ]),
        if (results.isEmpty)
          _buildEmptyState()
        else
          ...results.map((route) => _buildRouteCard(route)),
      ]);
    });
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      width: double.infinity,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.search_off_rounded,
              size: 32, color: AppColors.secondary),
        ),
        const SizedBox(height: 12),
        const Text('No routes found',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        const SizedBox(height: 4),
        const Text('Try a different destination',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _buildStopBasedRoutes() {
    return Consumer<BusProvider>(builder: (context, busProvider, _) {
      final stopMatches = busProvider.stopMatches;
      final routesMap = busProvider.routesViaStop;

      if (stopMatches.isEmpty || busProvider.searchQuery.isEmpty) {
        return const SizedBox.shrink();
      }

      final directRouteIds =
          busProvider.searchResults.map((r) => r.id).toSet();
      final stopRouteEntries = <_StopRouteEntry>[];

      for (final stop in stopMatches) {
        final sid = stop.id ?? stop.stopId;
        final routes = routesMap[sid] ?? [];
        for (final route in routes) {
          if (!directRouteIds.contains(route.id)) {
            stopRouteEntries.add(_StopRouteEntry(stop: stop, route: route));
          }
        }
      }

      if (stopRouteEntries.isEmpty && !busProvider.loadingStopRoutes) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.alt_route_rounded,
                  size: 14, color: Color(0xFF16A34A)),
            ),
            const SizedBox(width: 8),
            const Text('Routes via Bus Stops',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const Spacer(),
            if (busProvider.loadingStopRoutes)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            if (!busProvider.loadingStopRoutes && stopRouteEntries.isNotEmpty)
              Text(
                '${stopRouteEntries.length} routes',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted.withOpacity(0.7),
                    fontWeight: FontWeight.w500),
              ),
          ]),
          const SizedBox(height: 10),
          if (busProvider.loadingStopRoutes && stopRouteEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Searching bus stops...',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ...stopRouteEntries
              .take(8)
              .map((entry) => _buildStopRouteCard(entry)),
        ],
      );
    });
  }

  Widget _buildStopRouteCard(_StopRouteEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF16A34A).withOpacity(0.25),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onRouteTapped(entry.route),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: entry.route.routeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(entry.route.routeNumber,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.route.displayRoute,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.place_rounded,
                        size: 11,
                        color: const Color(0xFF16A34A).withOpacity(0.8)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'Passes through ${entry.stop.name}',
                        style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF16A34A).withOpacity(0.9),
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('VIA',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                      letterSpacing: 0.5)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildStopItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showArrow = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1628),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (showArrow)
            const Icon(Icons.chevron_right_rounded,
                size: 14, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  Widget _buildRouteCard(BusRoute route) {
    final isExpanded = _expandedRouteId == route.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? AppColors.secondary.withOpacity(0.4)
              : AppColors.divider,
          width: isExpanded ? 1.5 : 0.5,
        ),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => _onRouteTapped(route),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: route.routeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(route.routeNumber,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.displayRoute,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(
                      route.from.isNotEmpty
                          ? 'Tap to see active buses'
                          : '',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
            ]),
          ),
        ),
        if (isExpanded) ...[
          Divider(
              height: 1, color: AppColors.divider.withOpacity(0.5)),
          _loadingBuses
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Finding active buses...',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ))
              : _routeBuses.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_bus_rounded,
                              size: 16, color: AppColors.textMuted),
                          SizedBox(width: 8),
                          Text('No active buses on this route',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted)),
                        ],
                      ))
                  : Column(
                      children:
                          _routeBuses.map((bus) => _buildBusRow(bus)).toList(),
                    ),
        ],
      ]),
    );
  }

  Widget _buildBusRow(Map<String, dynamic> bus) {
    final busId = bus['id'] as String;
    final busNumber = bus['bus_number'] as String? ?? '---';
    final driverName = bus['driver_name'] as String? ?? 'Driver';
    final crowd = bus['crowd_level'] as String? ?? 'low';
    final speed = (bus['speed_kmh'] as num?)?.toDouble() ?? 0.0;

    final etaLoading = _busEtaLoading[busId] ?? false;
    final etaMin = _busEtas[busId] ?? _localEta(bus);
    final stopName = _nearestStop?.name ?? 'nearest stop';
    final isTracking = _trackingBusId == busId;

    Color crowdColor;
    String crowdLabel;
    switch (crowd) {
      case 'high':
      case 'full':
        crowdColor = const Color(0xFFDC2626);
        crowdLabel = 'Crowded';
        break;
      case 'medium':
        crowdColor = const Color(0xFFF59E0B);
        crowdLabel = 'Moderate';
        break;
      default:
        crowdColor = const Color(0xFF16A34A);
        crowdLabel = 'Available';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: AppColors.divider.withOpacity(0.4), width: 0.5)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isTracking
                  ? AppColors.secondary.withOpacity(0.2)
                  : AppColors.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_bus_rounded,
                size: 18, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bus $busNumber · $driverName',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.circle, size: 7, color: crowdColor),
                  const SizedBox(width: 4),
                  Text(crowdLabel,
                      style: TextStyle(fontSize: 11, color: crowdColor)),
                  const SizedBox(width: 8),
                  Icon(Icons.speed_rounded,
                      size: 11,
                      color: AppColors.textMuted.withOpacity(0.7)),
                  const SizedBox(width: 3),
                  Text('${speed.toStringAsFixed(0)} km/h',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted.withOpacity(0.7))),
                ]),
                const SizedBox(height: 3),
                Text('Arriving at $stopName',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: etaMin <= 5
                  ? const Color(0xFFE8F5E9)
                  : etaMin <= 15
                      ? const Color(0xFFFFF8E1)
                      : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: etaLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Column(
                    children: [
                      Text('$etaMin',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: etaMin <= 5
                                  ? const Color(0xFF16A34A)
                                  : etaMin <= 15
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFDC2626))),
                      const Text('MIN',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted)),
                    ],
                  ),
          ),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _onBoardBus(busId, busNumber),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isTracking
                  ? const Color(0xFF16A34A)
                  : AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isTracking
                    ? const Color(0xFF16A34A)
                    : AppColors.secondary.withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isTracking
                      ? Icons.check_circle_rounded
                      : Icons.directions_bus_rounded,
                  size: 16,
                  color: isTracking ? Colors.white : AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  isTracking ? 'Tracking this bus' : 'Board Bus',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isTracking ? Colors.white : AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _StopRouteEntry {
  final StopModel stop;
  final BusRoute route;
  const _StopRouteEntry({required this.stop, required this.route});
}
