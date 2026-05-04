import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart' hide RouteData;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bus_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/bus_card.dart';
import '../../models/bus_model.dart';
import 'package:geolocator/geolocator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _defaultLocation = LatLng(6.9271, 79.8612);
  LatLng _userLocation = _defaultLocation;
  final MapController _mapController = MapController();
  bool _mapReady = false;

  String get _tileUrl =>
      'https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png'
      '?key=${dotenv.env['MAPTILER_KEY'] ?? ''}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<TripProvider>().loadTripHistory();
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<UserProvider>().setUser(auth.currentUser!);
      }
      // Load buses at default first so screen isn't empty
      context.read<BusProvider>().loadAll(
          _defaultLocation.latitude, _defaultLocation.longitude);

      // Then get real GPS and reload
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) return;

        // Try last known first (instant)
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() {
            _userLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
          });
          if (_mapReady) _mapController.move(_userLocation, 12.5);
          context.read<BusProvider>().loadAll(
              lastKnown.latitude, lastKnown.longitude);
        }

        // Then get accurate position
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));

        if (mounted) {
          setState(() {
            _userLocation = LatLng(position.latitude, position.longitude);
          });
          if (_mapReady) _mapController.move(_userLocation, 12.5);
          context.read<BusProvider>().loadAll(
              position.latitude, position.longitude);
        }
      } catch (e) {
        debugPrint('[Dashboard] GPS error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildMapPreview(),
                const SizedBox(height: 8),
                _buildQuickActions(),
                const SizedBox(height: 16),
                _buildNearbyBuses(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return Container(
          width: double.infinity,
          color: AppColors.primary,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Helpers.getGreeting(),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.lightBlue)),
                      const SizedBox(height: 4),
                      Text(userProvider.user?.fullName ?? 'User',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_outlined,
                            size: 18, color: Colors.white)),
                      Positioned(top: 2, right: 2,
                        child: Container(
                          width: 9, height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary, width: 2)))),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapPreview() {
    return Consumer<BusProvider>(
      builder: (context, busProvider, _) {
        final liveBuses = busProvider.nearbyBuses
            .where((b) => b.currentLat != null && b.currentLng != null)
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10, offset: const Offset(0, 4))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onTap: () {
                  final shell = StatefulNavigationShell.maybeOf(context);
                  shell?.goBranch(1);
                },
                child: SizedBox(
                  height: 180,
                  child: Stack(children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _userLocation,
                        initialZoom: 12.5,
                        onMapReady: () {
                          setState(() => _mapReady = true);
                          _mapController.move(_userLocation, 12.5);
                        },
                        interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _tileUrl,
                          userAgentPackageName: 'com.busgo.client',
                        ),
                        // User location dot
                        MarkerLayer(markers: [
                          Marker(
                            point: _userLocation,
                            width: 16, height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2.5),
                                boxShadow: [BoxShadow(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.5),
                                    blurRadius: 6)]),
                            )),
                        ]),
                        // Live bus markers
                        MarkerLayer(
                          markers: liveBuses.map((bus) {
                            final pos = LatLng(
                                bus.currentLat!, bus.currentLng!);
                            return Marker(
                              point: pos,
                              width: 32, height: 32,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _crowdColor(bus.crowdLevel),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                  boxShadow: [BoxShadow(
                                      color: _crowdColor(bus.crowdLevel)
                                          .withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2))]),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.directions_bus,
                                        size: 12, color: Colors.white),
                                    Text(bus.routeNumber,
                                        style: const TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                  ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    // Live bus count badge
                    Positioned(bottom: 6, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          const Icon(Icons.circle,
                              size: 6, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${liveBuses.length} BUS${liveBuses.length == 1 ? '' : 'ES'} LIVE',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5)),
                        ])),
                    ),

                    // Live Map label
                    Positioned(bottom: 6, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4)]),
                        child: const Text('Live Map',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      )),

                    // Tap hint
                    Positioned(bottom: 10, left: 0, right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1B2A)
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF1A6FA8)
                                    .withValues(alpha: 0.5))),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_full_rounded,
                                  size: 11, color: Color(0xFF5BB8F5)),
                              SizedBox(width: 4),
                              Text('Tap to open full map',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF5BB8F5))),
                            ]),
                        ),
                      )),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _crowdColor(CrowdLevel level) {
    switch (level) {
      case CrowdLevel.high:     return const Color(0xFFDC2626);
      case CrowdLevel.moderate: return const Color(0xFFF59E0B);
      case CrowdLevel.low:      return const Color(0xFF16A34A);
    }
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickAction(
            icon: Icons.search_rounded,
            label: 'Search',
            color: const Color(0xFFEDEAFF),
            iconColor: const Color(0xFF5E35B1),
            onTap: () {
              final shell = StatefulNavigationShell.maybeOf(context);
              shell?.goBranch(2);
            },
          ),
          _QuickAction(
            icon: Icons.notifications_active_rounded,
            label: 'Emergency',
            color: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFE53935),
            onTap: () => context.push('/emergency'),
          ),
          _QuickAction(
            icon: Icons.phone_android_rounded,
            label: 'My QR',
            color: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF43A047),
            onTap: () => context.push('/qr'),
          ),
          _QuickAction(
            icon: Icons.assignment_rounded,
            label: 'History',
            color: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFF57C00),
            onTap: () => context.push('/history'),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyBuses() {
    return Consumer<BusProvider>(
      builder: (context, busProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Text('Nearby Buses',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ),
            if (busProvider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (busProvider.nearbyBuses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('No buses nearby',
                    style: TextStyle(color: AppColors.textMuted)),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: busProvider.nearbyBuses.map((bus) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BusCard(bus: bus),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? iconColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22, color: iconColor ?? Colors.white)),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ]),
        ),
      ),
    );
  }
}









