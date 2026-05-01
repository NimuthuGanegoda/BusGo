import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/token_service.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline   = false;
  bool _isLoading  = true;
  Map<String, dynamic>? _driver;
  Map<String, dynamic>? _bus;

  Timer?    _locationTimer;
  Position? _lastPosition;

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _loadDriver();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDriver() async {
    try {
      final tokens = TokenService();
      final api    = ApiService(tokens);
      final data   = await api.get('/users/me');
      final bus    = await api.get('/driver/bus');
      setState(() {
        _driver = data as Map<String, dynamic>?;
        _bus    = bus as Map<String, dynamic>?;
      });
    } catch (e) {
      debugPrint('[HomeScreen] Load error: $e');
    } finally {
      setState(() => _isLoading = false);
      await _toggleOnline(true);
    }
  }

  // ── GPS ────────────────────────────────────────────────────────────────────

  Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permission permanently denied. Please enable in Settings.'),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    }
    return permission == LocationPermission.whileInUse ||
           permission == LocationPermission.always;
  }

  Future<void> _startSendingLocation() async {
    final granted = await _requestLocationPermission();
    if (!granted) {
      setState(() => _isOnline = false);
      return;
    }

    // Send immediately
    await _sendCurrentLocation();

    // Then every 10 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendCurrentLocation();
    });

    debugPrint('[HomeScreen] GPS started');
  }

  void _stopSendingLocation() {
    _locationTimer?.cancel();
    _locationTimer = null;
    debugPrint('[HomeScreen] GPS stopped');
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));

      final speed = position.speed >= 0
          ? position.speed * 3.6  // m/s to km/h
          : 0.0;

      await _locationService.updateLocation(
        lat:      position.latitude,
        lng:      position.longitude,
        speedKmh: speed,
        heading:  position.heading >= 0 ? position.heading : null,
      );

      setState(() => _lastPosition = position);
      debugPrint('[HomeScreen] ✅ GPS sent: ${position.latitude}, ${position.longitude} @ ${speed.toStringAsFixed(1)} km/h');
    } catch (e) {
      debugPrint('[HomeScreen] GPS error: $e');
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _isOnline = value);
    if (value) {
      await _startSendingLocation();
    } else {
      _stopSendingLocation();
    }
  }

  Future<void> _logout() async {
    _stopSendingLocation();
    await TokenService().clear();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final name      = _driver?['full_name'] as String? ?? 'Driver';
    final busNumber = _bus?['bus_number']   as String? ?? '---';
    final routeName = (_bus?['bus_routes']  as Map<String, dynamic>?)?['route_name']
        as String? ?? 'No route assigned';

    final lat = _lastPosition?.latitude;
    final lng = _lastPosition?.longitude;
    final spd = _lastPosition != null
        ? (_lastPosition!.speed * 3.6).toStringAsFixed(0)
        : '0';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BUSGO Drive'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Driver header ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF42A5F5)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'D',
                          style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello, ${name.split(' ').first}!',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          Text('Bus: $busNumber — $routeName',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      )),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // ── Online toggle ──────────────────────────────────────
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isOnline
                                ? AppColors.success.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.circle,
                              color: _isOnline
                                  ? AppColors.success
                                  : Colors.grey),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isOnline
                                ? 'You are Online'
                                : 'You are Offline',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            Text(_isOnline
                                ? 'GPS active — passengers can see your bus'
                                : 'Go online to share your location',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12)),
                          ],
                        )),
                        Switch(
                          value: _isOnline,
                          onChanged: _toggleOnline,
                          activeColor: AppColors.success,
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Live GPS status card ───────────────────────────────
                  if (_isOnline)
                    Card(
                      color: AppColors.success.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: AppColors.success.withOpacity(0.3))),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          const Icon(Icons.gps_fixed,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('GPS Active',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success)),
                              if (lat != null)
                                Text(
                                  '${lat.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}  •  $spd km/h',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted)),
                              if (lat == null)
                                const Text('Acquiring location...',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                            ],
                          )),
                          if (lat == null)
                            const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.success)),
                        ]),
                      ),
                    ),

                  if (_isOnline) const SizedBox(height: 16),

                  // ── Stats ──────────────────────────────────────────────
                  Row(children: [
                    _StatCard(
                        label: 'Bus',
                        value: busNumber,
                        icon: Icons.directions_bus),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'Speed',
                        value: '${spd}km/h',
                        icon: Icons.speed),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'Status',
                        value: _isOnline ? 'Live' : 'Off',
                        icon: Icons.circle),
                  ]),
                  const SizedBox(height: 16),

                  // ── Quick actions ──────────────────────────────────────
                  const Text('Quick Actions',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _ActionCard(
                          icon: Icons.qr_code_scanner,
                          label: 'Scanner',
                          color: AppColors.primary,
                          onTap: () {}),
                      _ActionCard(
                          icon: Icons.map,
                          label: 'Route Map',
                          color: Colors.teal,
                          onTap: () {}),
                      _ActionCard(
                          icon: Icons.warning_amber,
                          label: 'Emergency',
                          color: AppColors.error,
                          onTap: () {}),
                      _ActionCard(
                          icon: Icons.history,
                          label: 'Trip History',
                          color: Colors.orange,
                          onTap: () {}),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ]),
          ),
        ),
      );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 24)),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
      );
}







