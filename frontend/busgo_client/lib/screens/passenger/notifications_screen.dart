import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../services/token_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  List<Map<String, dynamic>> _notifications = [];
  Map<String, dynamic>? _lastDismissed;
  int? _lastDismissedIndex;
  bool _loadingData = true;
  String? _token;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    // Load token first, then fetch
    TokenService().getAccessToken().then((t) {
      _token = t;
      _fetchFromBackend();
    });

    // Poll every 10 s for new alerts
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchFromBackend(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FETCH — GET /api/notifications?category=bus_alert
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _fetchFromBackend({bool silent = false}) async {
    if (!silent) setState(() => _loadingData = true);

    final token = _token ?? await TokenService().getAccessToken();
    if (token == null) {
      if (mounted) setState(() => _loadingData = false);
      return;
    }
    _token = token;

    try {
      final uri = Uri.parse('$kBaseUrlDev/notifications').replace(
        queryParameters: {
          'category':  'bus_alert',
          'page':      '1',
          'page_size': '100',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data']?['notifications'] as List?) ?? [];
        final now  = DateTime.now();

        final fetched = list.map((item) {
          final m         = item as Map<String, dynamic>;
          final createdAt =
              DateTime.tryParse(m['created_at'] as String? ?? '')?.toLocal() ??
                  now;
          return {
            'id':         m['id']      as String? ?? '',
            'title':      m['title']   as String? ?? '',
            'body':       m['body']    as String? ?? '',
            'isRead':     m['is_read'] as bool?   ?? false,
            'meta':       m['meta']    as Map<String, dynamic>? ?? {},
            'time':       _formatTime(createdAt),
            'group':      _groupLabel(createdAt, now),
            '_createdAt': createdAt,
          };
        }).toList();

        if (mounted) {
          setState(() {
            _notifications = fetched;
            _loadingData   = false;
          });
          if (!silent) _animController..reset()..forward();
        }
      } else {
        debugPrint('[NotificationsScreen] ${response.statusCode}: ${response.body}');
        if (mounted) setState(() => _loadingData = false);
      }
    } catch (e) {
      debugPrint('[NotificationsScreen] fetch error: $e');
      if (mounted) setState(() => _loadingData = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MARK ALL READ
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _markAllRead() async {
    setState(() {
      for (final n in _notifications) n['isRead'] = true;
    });
    final token = _token;
    if (token == null) return;
    try {
      await http.patch(
        Uri.parse('$kBaseUrlDev/notifications/read-all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[NotificationsScreen] markAllRead: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MARK ONE READ
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _markOneRead(Map<String, dynamic> n) async {
    if (n['isRead'] == true) return;
    setState(() => n['isRead'] = true);
    final token = _token;
    if (token == null) return;
    try {
      await http.patch(
        Uri.parse('$kBaseUrlDev/notifications/${n['id']}/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[NotificationsScreen] markOneRead: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _deleteFromBackend(String id) async {
    final token = _token;
    if (token == null) return;
    try {
      await http.delete(
        Uri.parse('$kBaseUrlDev/notifications/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[NotificationsScreen] delete: $e');
    }
  }

  Future<void> _onRefresh() async => _fetchFromBackend();

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatTime(DateTime dt) {
    final h    = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m    = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  String _groupLabel(DateTime dt, DateTime now) {
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date      = DateTime(dt.year, dt.month, dt.day);
    if (date == today)     return 'TODAY';
    if (date == yesterday) return 'YESTERDAY';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  int get _unreadCount =>
      _notifications.where((n) => n['isRead'] == false).length;

  TextStyle _inter({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing);

  Animation<double> _fade(int i) {
    final s = (i * 0.04).clamp(0.0, 0.65);
    final e = (s + 0.22).clamp(0.0, 1.0);
    return CurvedAnimation(
        parent: _animController,
        curve: Interval(s, e, curve: Curves.easeOut));
  }

  Animation<Offset> _slide(int i) {
    final s = (i * 0.04).clamp(0.0, 0.65);
    final e = (s + 0.22).clamp(0.0, 1.0);
    return Tween<Offset>(begin: const Offset(0, 12), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _animController,
            curve: Interval(s, e, curve: Curves.easeOut)));
  }

  Widget _anim(int i, Widget child) => AnimatedBuilder(
        animation: _animController,
        builder: (_, __) => Opacity(
          opacity: _fade(i).value,
          child: Transform.translate(offset: _slide(i).value, child: child),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final List<dynamic> items = [];
    String? lastGroup;
    for (final n in _notifications) {
      final group = n['group'] as String? ?? '';
      if (group != lastGroup) {
        lastGroup = group;
        items.add(lastGroup);
      }
      items.add(n);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            _anim(0, _buildHeader()),
            Expanded(
              child: _loadingData
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1A6FA8)))
                  : RefreshIndicator(
                      color:           const Color(0xFF1A6FA8),
                      backgroundColor: const Color(0xFF1A3A5C),
                      onRefresh:       _onRefresh,
                      child: _notifications.isEmpty
                          ? CustomScrollView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverFillRemaining(
                                    child: _buildEmptyState()),
                              ],
                            )
                          : ListView.builder(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                if (item is String) {
                                  return _anim(
                                      1 + index,
                                      _buildGroupHeader(item));
                                }
                                return _anim(
                                    1 + index,
                                    _buildNotificationCard(
                                        item as Map<String, dynamic>));
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════
  // HEADER
  // ═════════════════════════════════════════════════
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A5C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF1A6FA8).withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text('Bus Alerts',
              style: _inter(size: 18, weight: FontWeight.w700)),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$_unreadCount',
                  style: _inter(size: 10, weight: FontWeight.w700)),
            ),
          ],
          const Spacer(),
          if (_notifications.isNotEmpty)
            GestureDetector(
              onTap: _markAllRead,
              child: Text('Mark all read',
                  style: _inter(
                      size: 11,
                      weight: FontWeight.w600,
                      color: const Color(0xFF5BB8F5))),
            ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════
  // GROUP HEADER
  // ═════════════════════════════════════════════════
  Widget _buildGroupHeader(String group) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(group,
          style: _inter(
              size: 11,
              weight: FontWeight.w700,
              color: const Color(0xFF5BB8F5).withValues(alpha: 0.6),
              letterSpacing: 0.6)),
    );
  }

  // ═════════════════════════════════════════════════
  // NOTIFICATION CARD
  // ═════════════════════════════════════════════════
  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final isRead = n['isRead'] as bool;

    return Dismissible(
      key: Key(n['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded,
            color: Colors.white, size: 24),
      ),
      onDismissed: (_) {
        final id    = n['id'] as String;
        final index = _notifications.indexOf(n);
        setState(() {
          _lastDismissed      = n;
          _lastDismissedIndex = index;
          _notifications.remove(n);
        });
        _deleteFromBackend(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alert dismissed', style: _inter(size: 13)),
            backgroundColor: const Color(0xFF1A3A5C),
            action: SnackBarAction(
              label: 'Undo',
              textColor: const Color(0xFFF0C040),
              onPressed: () {
                if (_lastDismissed != null && _lastDismissedIndex != null) {
                  setState(() => _notifications.insert(
                      _lastDismissedIndex!, _lastDismissed!));
                  final token = _token;
                  if (token != null) {
                    http
                        .post(
                          Uri.parse('$kBaseUrlDev/notifications'),
                          headers: {
                            'Authorization': 'Bearer $token',
                            'Content-Type':  'application/json',
                          },
                          body: jsonEncode({
                            'category': 'bus_alert',
                            'title':    _lastDismissed!['title'],
                            'body':     _lastDismissed!['body'],
                            'meta':     _lastDismissed!['meta'] ?? {},
                          }),
                        )
                        .catchError((e) =>
                            debugPrint('[NotificationsScreen] undo: $e'));
                  }
                }
              },
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _markOneRead(n),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isRead
                ? const Color(0xFF1A3A5C).withValues(alpha: 0.5)
                : const Color(0xFF1A3A5C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? const Color(0xFF1A6FA8).withValues(alpha: 0.15)
                  : const Color(0xFF1A6FA8).withValues(alpha: 0.4),
            ),
            boxShadow: isRead
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF1A6FA8).withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                if (!isRead)
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A6FA8),
                      borderRadius: const BorderRadius.only(
                        topLeft:    Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A6FA8)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                              Icons.directions_bus_rounded,
                              size: 22,
                              color: Color(0xFF1A6FA8)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n['title'] as String,
                                  style: _inter(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: isRead
                                          ? const Color(0xFF8AAFD4)
                                          : Colors.white)),
                              const SizedBox(height: 3),
                              Text(n['body'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _inter(
                                      size: 12,
                                      color: isRead
                                          ? const Color(0xFF5BB8F5)
                                              .withValues(alpha: 0.6)
                                          : const Color(0xFF8AAFD4))),
                              const SizedBox(height: 6),
                              Text(n['time'] as String,
                                  style: _inter(
                                      size: 10,
                                      color: const Color(0xFF5BB8F5)
                                          .withValues(alpha: 0.5))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isRead)
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0C040),
                                borderRadius: BorderRadius.circular(4)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════
  // EMPTY STATE
  // ═════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_bus_rounded,
              size: 64, color: Color(0xFF1A3A5C)),
          const SizedBox(height: 16),
          Text('No bus alerts yet',
              style: _inter(
                  size: 16,
                  weight: FontWeight.w600,
                  color: const Color(0xFF5BB8F5))),
          const SizedBox(height: 6),
          Text("You'll be notified when your bus is near.",
              style: _inter(
                  size: 13,
                  color: const Color(0xFF5BB8F5).withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          Text('Pull down to refresh',
              style: _inter(
                  size: 11,
                  color: const Color(0xFF5BB8F5).withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
