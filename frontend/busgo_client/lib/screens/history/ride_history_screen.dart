import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

const _cyan   = Color(0xFF4ECDC4);
const _bg     = Color(0xFF040A14);
const _card   = Color(0xFF0A1628);
const _border = Color(0x1AFFFFFF);

// ── Trip model ────────────────────────────────────────────────────────────────
class _Trip {
  final String  id;
  final String  busNumber;
  final String  routeNumber;
  final String  from;
  final String  to;
  final String  date;       // formatted display date
  final String  time;
  final String  duration;
  final double  fare;
  final String  status;
  final DateTime boardedAt;

  const _Trip({
    required this.id,
    required this.busNumber,
    required this.routeNumber,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.duration,
    required this.fare,
    required this.status,
    required this.boardedAt,
  });

  factory _Trip.fromJson(Map<String, dynamic> j) {
    final boardedStr  = j['boarded_at']   as String? ?? '';
    final alightedStr = j['alighted_at']  as String?;
    final boardedAt   = DateTime.tryParse(boardedStr)?.toLocal() ?? DateTime.now();
    final alightedAt  = alightedStr != null
        ? DateTime.tryParse(alightedStr)?.toLocal() : null;

    // Duration
    String duration = '';
    if (alightedAt != null) {
      final diff = alightedAt.difference(boardedAt);
      if (diff.inHours > 0) {
        duration = '${diff.inHours} hr ${diff.inMinutes.remainder(60)} min';
      } else {
        duration = '${diff.inMinutes} min';
      }
    }

    // Date display
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripDay = DateTime(boardedAt.year, boardedAt.month, boardedAt.day);
    String dateLabel;
    if (tripDay == today) {
      dateLabel = 'Today';
    } else if (tripDay == today.subtract(const Duration(days: 1))) {
      dateLabel = 'Yesterday';
    } else {
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      dateLabel = '${days[boardedAt.weekday - 1]} ${boardedAt.day} '
          '${months[boardedAt.month - 1]}';
    }

    final timeStr = '${boardedAt.hour.toString().padLeft(2, '0')}:'
        '${boardedAt.minute.toString().padLeft(2, '0')}';

    final busRoutes = j['bus_routes'] as Map<String, dynamic>?
                   ?? j['bus_route']  as Map<String, dynamic>?
                   ?? {};
    final buses     = j['buses']      as Map<String, dynamic>? ?? {};

    return _Trip(
      id:          j['id']      as String? ?? '',
      busNumber:   buses['bus_number'] as String?
                   ?? busRoutes['bus_number'] as String? ?? 'Bus',
      routeNumber: busRoutes['route_number'] as String? ?? '—',
      from:        (j['boarding_stop']  as Map?)?['stop_name']  as String?
                   ?? busRoutes['origin']      as String? ?? '',
      to:          (j['alighting_stop'] as Map?)?['stop_name'] as String?
                   ?? busRoutes['destination'] as String? ?? '',
      date:        dateLabel,
      time:        timeStr,
      duration:    duration,
      fare:        (j['fare_lkr'] as num?)?.toDouble() ?? 0,
      status:      j['status'] as String? ?? 'completed',
      boardedAt:   boardedAt,
    );
  }

  String get monthKey {
    const months = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];
    return '${months[boardedAt.month - 1]} ${boardedAt.year}';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});
  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<_Trip> _allTrips    = [];
  bool        _loading     = true;
  String?     _error;
  int         _page        = 1;
  bool        _hasMore     = true;
  bool        _loadingMore = false;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (_hasMore && !_loadingMore) _loadMore();
    }
  }

  Future<void> _loadTrips({bool refresh = false}) async {
    if (refresh) {
      setState(() { _page = 1; _allTrips = []; _hasMore = true; _loading = true; _error = null; });
    }

    try {
      final token = await context.read<AuthProvider>().getAccessToken();
      if (token == null) { setState(() { _loading = false; _error = 'Not logged in'; }); return; }

      final res = await http.get(
        Uri.parse('$kBaseUrlDev/trips?status=completed&page=$_page&page_size=20'),
        headers: { 'Authorization': 'Bearer $token', 'Content-Type': 'application/json' },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body  = jsonDecode(res.body) as Map<String, dynamic>;
        final raw   = body['data'] as List<dynamic>? ?? [];
        final trips = raw.whereType<Map<String, dynamic>>()
            .map(_Trip.fromJson).toList();

        setState(() {
          _allTrips = [..._allTrips, ...trips];
          _hasMore  = trips.length == 20;
          _loading  = false;
          _error    = null;
        });
      } else {
        setState(() { _loading = false; _error = 'Failed to load trips'; });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Connection error'; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() { _loadingMore = true; _page++; });
    await _loadTrips();
    setState(() => _loadingMore = false);
  }

  // ── Derived ────────────────────────────────────────────────────────────────
  List<_Trip> get _filtered {
    if (_searchQuery.isEmpty) return _allTrips;
    final q = _searchQuery.toLowerCase();
    return _allTrips.where((t) =>
        t.busNumber.toLowerCase().contains(q) ||
        t.routeNumber.toLowerCase().contains(q) ||
        t.from.toLowerCase().contains(q) ||
        t.to.toLowerCase().contains(q)).toList();
  }

  // Stats
  int    get _totalTrips => _allTrips.length;
  double get _totalSpent => _allTrips.fold(0, (s, t) => s + t.fare);
  int    get _routeCount => _allTrips.map((t) => t.routeNumber).toSet().length;

  // Group by month
  Map<String, List<_Trip>> get _grouped {
    final map  = <String, List<_Trip>>{};
    for (final t in _filtered) {
      map.putIfAbsent(t.monthKey, () => []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildHeader(),
        _buildStats(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF0B1A2E), Color(0xFF132F54), Color(0xFF1E5AA8)]),
      borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(children: [
        Row(children: [
          GestureDetector(onTap: () => context.pop(),
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 20, color: Colors.white))),
          const Expanded(child: Text('Ride History',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white))),
          GestureDetector(onTap: () => _loadTrips(refresh: true),
            child: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.refresh_rounded,
                  size: 20, color: Colors.white))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Container(height: 42,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: TextField(controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13, color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search trips...',
                hintStyle: TextStyle(fontSize: 13,
                    color: Colors.white.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search_rounded, size: 18,
                    color: Colors.white.withOpacity(0.6)),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _searchController.clear();
                            setState(() => _searchQuery = ''); },
                        child: Icon(Icons.close_rounded, size: 16,
                            color: Colors.white.withOpacity(0.6)))
                    : null)))),
        ]),
      ]))));

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _buildStats() => Container(
    margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _cyan.withOpacity(0.2), width: 1.5)),
    child: Row(children: [
      _statBox(_loading ? '—' : '$_totalTrips',
          'Trips', _cyan, Icons.directions_bus_rounded),
      _statDivider(),
      _statBox(_loading ? '—' : 'Rs ${_totalSpent.toStringAsFixed(0)}',
          'Spent', const Color(0xFF2ECC71),
          Icons.account_balance_wallet_rounded),
      _statDivider(),
      _statBox(_loading ? '—' : '$_routeCount',
          'Routes', AppColors.warning, Icons.route_rounded),
    ]));

  Widget _statDivider() => Container(
      width: 1, height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: _border);

  Widget _statBox(String value, String label, Color color, IconData icon) =>
      Expanded(child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color), const SizedBox(width: 4),
          Flexible(child: Text(value, style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w800, color: color),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10,
            color: Colors.white.withOpacity(0.4))),
      ]));

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(
        color: _cyan));
    if (_error != null) return Center(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_rounded, color: _cyan, size: 40),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: Colors.white54)),
      const SizedBox(height: 12),
      TextButton(onPressed: () => _loadTrips(refresh: true),
          child: const Text('Retry', style: TextStyle(color: _cyan))),
    ]));
    if (_filtered.isEmpty) return _buildEmptyState();

    final grouped = _grouped;
    final months  = grouped.keys.toList();

    return RefreshIndicator(
      color: _cyan,
      onRefresh: () => _loadTrips(refresh: true),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: months.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == months.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(
                  strokeWidth: 2, color: _cyan)));
          }
          final month = months[i];
          final trips = grouped[month]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthHeader(month, trips.length),
              ...trips.map(_buildTripCard),
              const SizedBox(height: 8),
            ]);
        }),
    );
  }

  Widget _buildMonthHeader(String month, int count) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _cyan.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_month_rounded, size: 12,
              color: _cyan.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text(month.toUpperCase(), style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _cyan, letterSpacing: 0.5)),
        ])),
      const Spacer(),
      Text('$count trip${count == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 11,
              color: Colors.white.withOpacity(0.3))),
    ]));

  Widget _buildTripCard(_Trip trip) {
    final hasFare    = trip.fare > 0;
    final hasRoute   = trip.from.isNotEmpty && trip.to.isNotEmpty;
    final hasDuration = trip.duration.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border)),
      child: IntrinsicHeight(child: Row(children: [
        // Left accent bar
        Container(width: 4, decoration: BoxDecoration(
          color: _cyan.withOpacity(0.6),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14)))),

        Expanded(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Bus icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_cyan.withOpacity(0.15), _cyan.withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: const Icon(Icons.directions_bus_rounded,
                  size: 22, color: _cyan)),
            const SizedBox(width: 12),

            // Trip info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Bus + route badge
              Row(children: [
                Text(
                  trip.busNumber.startsWith('Bus')
                      ? trip.busNumber
                      : 'Bus ${trip.busNumber}',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E5AA8).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text('Route ${trip.routeNumber}',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.white54,
                          fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 4),

              // From → To
              if (hasRoute)
                Row(children: [
                  Icon(Icons.route_rounded, size: 12,
                      color: _cyan.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Flexible(child: Text(
                    '${trip.from} → ${trip.to}',
                    style: TextStyle(fontSize: 12,
                        color: _cyan.withOpacity(0.8)),
                    overflow: TextOverflow.ellipsis)),
                ]),
              const SizedBox(height: 3),

              // Date · time · duration
              Row(children: [
                Text('${trip.date} · ${trip.time}',
                    style: TextStyle(fontSize: 11,
                        color: Colors.white.withOpacity(0.3))),
                if (hasDuration) ...[
                  Text(' · ', style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(0.2))),
                  Text(trip.duration, style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(0.3))),
                ],
              ]),
            ])),

            // Right — fare
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasFare
                      ? _cyan.withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: hasFare
                      ? Border.all(color: _cyan.withOpacity(0.2))
                      : null),
                child: Text(
                  hasFare
                      ? 'Rs ${trip.fare.toStringAsFixed(0)}'
                      : 'Cash',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: hasFare ? Colors.white : Colors.white38))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4)),
                child: const Text('Completed',
                    style: TextStyle(fontSize: 9,
                        color: Color(0xFF4ADE80),
                        fontWeight: FontWeight.w600))),
            ]),
          ])))
      ])));
  }

  Widget _buildEmptyState() => Center(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: _cyan.withOpacity(0.08), shape: BoxShape.circle),
      child: Icon(Icons.directions_bus_outlined, size: 40, color: _cyan)),
    const SizedBox(height: 16),
    const Text('No trips yet',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
            color: Colors.white)),
    const SizedBox(height: 4),
    Text(
      _searchQuery.isEmpty
          ? 'Your completed trips will appear here'
          : 'No trips match "$_searchQuery"',
      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      textAlign: TextAlign.center),
  ]));
}





