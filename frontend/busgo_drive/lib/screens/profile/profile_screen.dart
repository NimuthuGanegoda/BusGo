import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/token_service.dart';
import '../../widgets/stat_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int     _tripCount  = 0;
  double? _mlRating;
  bool    _loading    = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchTripCount(), _fetchRating()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchTripCount() async {
    try {
      final token = await TokenService().getAccessToken();
      if (token == null) return;

      // Try driver-specific history endpoint first
      for (final url in [
        '${ApiConfig.baseUrl}/driver/trip/history?page=1&page_size=50',
        '${ApiConfig.baseUrl}/trips?status=completed&page=1&page_size=50',
      ]) {
        final res = await http.get(Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 8));

        debugPrint('[Profile] $url → ${res.statusCode} (${res.body.length}b)');

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final data = body['data'];
          int count = 0;
          if (data is List) count = data.length;
          else if (data is Map) {
            count = (data['total'] as int?)
                ?? (data['total_count'] as int?)
                ?? (data['trips'] as List?)?.length
                ?? 0;
          }
          final meta = body['meta'] as Map<String, dynamic>?;
          final total = (meta?['total'] as int?) ?? (meta?['total_count'] as int?) ?? count;
          if (mounted) setState(() => _tripCount = total > 0 ? total : count);
          return;
        }
      }
    } catch (e) {
      debugPrint('[Profile] Trip count error: $e');
    }
  }

  Future<void> _fetchRating() async {
    try {
      final token = await TokenService().getAccessToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/driver/rating'),
        headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        final rating = (data?['ml_rating'] ?? data?['weighted_rating'] ?? data?['avg_rating']) as num?;
        if (mounted && rating != null) setState(() => _mlRating = rating.toDouble());
      }
    } catch (e) {
      debugPrint('[Profile] Rating error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AuthProvider>(builder: (context, auth, _) {
        final driver = auth.driver;
        if (driver == null) return const Center(child: Text('Not logged in'));

        return SingleChildScrollView(child: Column(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.primaryLight])),
            child: SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(children: [
                CircleAvatar(radius: 40, backgroundColor: Colors.white,
                  child: Text(driver.initials,
                    style: GoogleFonts.inter(fontSize: 28,
                        fontWeight: FontWeight.w800, color: AppColors.primary))),
                const SizedBox(height: 12),
                Text(driver.name, style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('ID: ${driver.employeeId}', style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFFE3F2FD))),
              ]),
            )),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Row(children: [
                Expanded(child: StatCard(
                  label: 'Trips',
                  value: _loading ? '...' : '$_tripCount',
                  icon: Icons.route, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () => context.push('/rating'),
                  child: StatCard(
                    label: 'My Rating',
                    value: _mlRating != null
                        ? _mlRating!.toStringAsFixed(1)
                        : 'View',
                    unit: _mlRating != null ? '/10' : '',
                    icon: Icons.star_outline, color: AppColors.warning))),
              ]),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 52,
                child: OutlinedButton.icon(
                  onPressed: () { auth.logout(); context.go('/login'); },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text('Sign Out', style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))))),
            ]),
          ),
        ]));
      }),
    );
  }
}
