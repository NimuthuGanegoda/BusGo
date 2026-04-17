import 'package:flutter/material.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final TextEditingController _destinationController = TextEditingController();
  List<Map<String, dynamic>> _recentSearches = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  void _loadRecentSearches() {
    setState(() {
      if (_recentSearches.isEmpty) {
        _recentSearches = [
          {'title': 'UCD Belfield', 'subtitle': 'Route 46A · Yesterday'},
          {'title': 'Heuston Station', 'subtitle': 'Route 79A · Mon 17 Mar'},
        ];
      }
    });
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;

    final newSearch = {
      'title': query.trim(),
      'subtitle': 'Custom Route · Just now',
    };

    setState(() {
      // Remove any existing identical searches to prevent duplicates
      _recentSearches.removeWhere((s) => s['title'] == newSearch['title']);
      _recentSearches.insert(0, newSearch);
      _isSearching = true;
    });
    
    _destinationController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // light background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildSearchBox(),
              const SizedBox(height: 28),
              _buildSectionTitle('Nearby Stops'),
              const SizedBox(height: 12),
              _buildNearbyStopCard(
                title: 'Stop 1342 — O\'Connell St',
                subtitle: '0.2 km · Routes: 39A, 40, 13',
              ),
              const SizedBox(height: 12),
              _buildNearbyStopCard(
                title: 'Stop 1198 — Parnell Sq',
                subtitle: '0.5 km · Routes: 46A, 7B',
              ),
              const SizedBox(height: 28),
              _buildSectionTitle('Recent Trips'),
              const SizedBox(height: 12),
              ..._recentSearches.map((search) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRecentTripCard(
                    title: search['title'] ?? '',
                    subtitle: search['subtitle'] ?? '',
                  ),
                );
              }),
              const SizedBox(height: 16),
              _buildSectionTitle('Search Results'),
              const SizedBox(height: 12),
              if (_isSearching && _recentSearches.isNotEmpty) ...[
                _buildSearchResultCard(
                  route: 'NEW',
                  routeColor: const Color(0xFFE91E63),
                  title: 'Current Location → ${_recentSearches.first['title']}',
                  subtitle: 'Direct Route · ~15 min',
                  eta: '5 min',
                  etaColor: const Color(0xFF2E7D32),
                  etaBg: const Color(0xFFE8F5E9),
                ),
                const SizedBox(height: 12),
              ],
              _buildSearchResultCard(
                route: '39A',
                routeColor: const Color(0xFF1976D2),
                title: 'Finglas → City Centre',
                subtitle: '16 stops · ~28 min',
                eta: '3 min',
                etaColor: const Color(0xFF2E7D32),
                etaBg: const Color(0xFFE8F5E9),
              ),
              const SizedBox(height: 12),
              _buildSearchResultCard(
                route: '13',
                routeColor: const Color(0xFF7B1FA2),
                title: 'Baggot St → Harristown',
                subtitle: '22 stops · ~41 min',
                eta: '11 min',
                etaColor: const Color(0xFFE65100),
                etaBg: const Color(0xFFFFF3E0),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF0B214A)),
        ),
        const SizedBox(width: 16),
        const Text(
          'Find Your Bus',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B214A),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF1976D2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Current Location',
                style: TextStyle(color: Color(0xFF78859A), fontSize: 14),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 3),
            child: Row(
              children: [
                SizedBox(
                  height: 20,
                  child: VerticalDivider(
                    color: Color(0xFFEEF0F4),
                    thickness: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    hintText: 'Where do you want to go?',
                    hintStyle: TextStyle(
                      color: Color(0xFF78859A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    color: Color(0xFF0B214A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _performSearch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0B214A),
      ),
    );
  }

  Widget _buildNearbyStopCard({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_bus_filled_outlined, color: Color(0xFF1976D2), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0B214A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF78859A), fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_right_alt, color: Color(0xFFCFD5E1), size: 18),
        ],
      ),
    );
  }

  Widget _buildRecentTripCard({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time_filled, color: Color(0xFF78859A), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0B214A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF78859A), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard({
    required String route,
    required Color routeColor,
    required String title,
    required String subtitle,
    required String eta,
    required Color etaColor,
    required Color etaBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: routeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              route,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0B214A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF78859A), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: etaBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              eta,
              style: TextStyle(
                color: etaColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
