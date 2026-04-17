import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _selectedTab = 0;

  final _tabs = const [
    {'label': 'All', 'icon': null},
    {'label': 'Bus Alerts', 'icon': Icons.directions_bus_rounded},
    {'label': 'Trips', 'icon': Icons.receipt_long_rounded},
    {'label': 'Emergency', 'icon': Icons.emergency_rounded},
    {'label': 'Payments', 'icon': Icons.payment_rounded},
  ];

  late List<Map<String, dynamic>> _notifications;
  Map<String, dynamic>? _lastDismissed;
  int? _lastDismissedIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _notifications = _buildInitialData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildInitialData() {
    return [
      {'id': 1, 'type': 'bus_alert', 'title': 'Bus 138 arriving soon', 'body': 'Route 138 Nugegoda → Colombo is 2 stops away from your location. Get ready to board.', 'time': '2 min ago', 'isRead': false, 'group': 'TODAY'},
      {'id': 2, 'type': 'trip', 'title': 'Trip completed successfully', 'body': 'Your trip on Route 163 Rajagiriya → Maharagama has been completed. Total fare: Rs 80.', 'time': '1 hour ago', 'isRead': false, 'group': 'TODAY'},
      {'id': 3, 'type': 'payment', 'title': 'Payment confirmed', 'body': 'Rs 80 payment for Route 163 has been processed successfully.', 'time': '1 hour ago', 'isRead': false, 'group': 'TODAY'},
      {'id': 4, 'type': 'bus_alert', 'title': 'Bus 163 is full', 'body': 'Route 163 Rajagiriya → Maharagama is at full capacity. Next bus in 18 min.', 'time': '3 hours ago', 'isRead': true, 'group': 'TODAY'},
      {'id': 5, 'type': 'system', 'title': 'QR Card refreshed', 'body': 'Your BusGo QR boarding card has been refreshed and is ready to use.', 'time': '5 hours ago', 'isRead': true, 'group': 'TODAY'},
      {'id': 6, 'type': 'emergency', 'title': 'Emergency alert resolved', 'body': 'The medical emergency reported on Bus 138 has been resolved by the driver.', 'time': 'Yesterday 14:32', 'isRead': true, 'group': 'YESTERDAY'},
      {'id': 7, 'type': 'trip', 'title': 'Rate your trip', 'body': 'How was your experience with Driver Kamal Perera on Route 138? Tap to rate.', 'time': 'Yesterday 09:15', 'isRead': false, 'group': 'YESTERDAY'},
      {'id': 8, 'type': 'payment', 'title': 'Monthly summary ready', 'body': 'You completed 24 trips and spent Rs 1,320 this month. View your full report.', 'time': 'Yesterday 08:00', 'isRead': true, 'group': 'YESTERDAY'},
      {'id': 9, 'type': 'bus_alert', 'title': 'Service disruption', 'body': 'Route 171 is experiencing delays due to road works near Boralla.', 'time': 'Mon 17 Mar · 16:45', 'isRead': true, 'group': 'MONDAY 17 MAR'},
      {'id': 10, 'type': 'system', 'title': 'Welcome to BusGo', 'body': 'Your account has been verified successfully. Start tracking buses in real time.', 'time': 'Mon 17 Mar · 09:00', 'isRead': true, 'group': 'MONDAY 17 MAR'},
    ];
  }

  int get _unreadCount => _notifications.where((n) => n['isRead'] == false).length;

  List<Map<String, dynamic>> get _filtered {
    final typeMap = {1: 'bus_alert', 2: 'trip', 3: 'emergency', 4: 'payment'};
    if (_selectedTab == 0) return _notifications;
    final type = typeMap[_selectedTab];
    return _notifications.where((n) => n['type'] == type).toList();
  }

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n['isRead'] = true;
      }
    });
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      _notifications = _buildInitialData();
    });
  }

  TextStyle _inter({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing,
    );
  }

  Animation<double> _fade(int i) {
    final s = (i * 0.04).clamp(0.0, 0.65);
    final e = (s + 0.22).clamp(0.0, 1.0);
    return CurvedAnimation(parent: _animController, curve: Interval(s, e, curve: Curves.easeOut));
  }

  Animation<Offset> _slide(int i) {
    final s = (i * 0.04).clamp(0.0, 0.65);
    final e = (s + 0.22).clamp(0.0, 1.0);
    return Tween<Offset>(begin: const Offset(0, 12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Interval(s, e, curve: Curves.easeOut)));
  }

  Widget _anim(int i, Widget child) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (_, __) => Opacity(
        opacity: _fade(i).value,
        child: Transform.translate(offset: _slide(i).value, child: child),
      ),
    );
  }

  Color _iconBg(String type) {
    switch (type) {
      case 'bus_alert': return const Color(0xFF1A6FA8).withValues(alpha: 0.2);
      case 'trip': return const Color(0xFF2E7D32).withValues(alpha: 0.2);
      case 'emergency': return const Color(0xFFE53935).withValues(alpha: 0.2);
      case 'payment': return const Color(0xFFF0C040).withValues(alpha: 0.2);
      default: return const Color(0xFF5BB8F5).withValues(alpha: 0.2);
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'bus_alert': return const Color(0xFF1A6FA8);
      case 'trip': return const Color(0xFF2E7D32);
      case 'emergency': return const Color(0xFFE53935);
      case 'payment': return const Color(0xFFF0C040);
      default: return const Color(0xFF5BB8F5);
    }
  }

  IconData _iconData(String type) {
    switch (type) {
      case 'bus_alert': return Icons.directions_bus_rounded;
      case 'trip': return Icons.receipt_long_rounded;
      case 'emergency': return Icons.emergency_rounded;
      case 'payment': return Icons.payment_rounded;
      default: return Icons.info_rounded;
    }
  }

  void _onTapNotification(Map<String, dynamic> n) {
    setState(() => n['isRead'] = true);
    final type = n['type'] as String;
    if (type == 'bus_alert') {
      context.go('/map');
    } else if (type == 'trip' || type == 'payment') {
      context.go('/history');
    } else if (type == 'emergency') {
      context.push('/emergency');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    // Build grouped list items
    final List<dynamic> items = [];
    String? lastGroup;
    for (final n in filtered) {
      if (n['group'] != lastGroup) {
        lastGroup = n['group'] as String;
        items.add(lastGroup); // string = group header
      }
      items.add(n); // map = notification
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            _anim(0, _buildHeader()),
            _anim(1, _buildFilterTabs()),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: const Color(0xFF1A6FA8),
                      backgroundColor: const Color(0xFF1A3A5C),
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          if (item is String) {
                            return _anim(2 + index, _buildGroupHeader(item));
                          }
                          final n = item as Map<String, dynamic>;
                          return _anim(2 + index, _buildNotificationCard(n));
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A5C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1A6FA8).withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text('Notifications', style: _inter(size: 18, weight: FontWeight.w700)),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$_unreadCount', style: _inter(size: 10, weight: FontWeight.w700)),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: _markAllRead,
            child: Text('Mark all read', style: _inter(size: 11, weight: FontWeight.w600, color: const Color(0xFF5BB8F5))),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════
  // FILTER TABS
  // ═════════════════════════════════════════════════
  Widget _buildFilterTabs() {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _tabs.length,
          itemBuilder: (context, i) {
            final tab = _tabs[i];
            final isActive = _selectedTab == i;
            final isEmergency = i == 3 && isActive;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEmergency
                        ? const Color(0xFFE53935)
                        : isActive
                            ? const Color(0xFF1A6FA8)
                            : const Color(0xFF1A3A5C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab['icon'] != null) ...[
                        Icon(tab['icon'] as IconData, size: 12, color: isActive ? Colors.white : const Color(0xFF5BB8F5)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        tab['label'] as String,
                        style: _inter(
                          size: 12,
                          weight: FontWeight.w600,
                          color: isActive ? Colors.white : const Color(0xFF5BB8F5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════
  // GROUP HEADER
  // ═════════════════════════════════════════════════
  Widget _buildGroupHeader(String group) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        group,
        style: _inter(
          size: 11,
          weight: FontWeight.w700,
          color: const Color(0xFF5BB8F5).withValues(alpha: 0.6),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════
  // NOTIFICATION CARD
  // ═════════════════════════════════════════════════
  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final isRead = n['isRead'] as bool;
    final type = n['type'] as String;

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
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) {
        final index = _notifications.indexOf(n);
        setState(() {
          _lastDismissed = n;
          _lastDismissedIndex = index;
          _notifications.remove(n);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification removed', style: _inter(size: 13)),
            backgroundColor: const Color(0xFF1A3A5C),
            action: SnackBarAction(
              label: 'Undo',
              textColor: const Color(0xFFF0C040),
              onPressed: () {
                if (_lastDismissed != null && _lastDismissedIndex != null) {
                  setState(() {
                    _notifications.insert(_lastDismissedIndex!, _lastDismissed!);
                  });
                }
              },
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _onTapNotification(n),
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
                // Left accent bar for unread
                if (!isRead)
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A6FA8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _iconBg(type),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(_iconData(type), size: 22, color: _iconColor(type)),
                        ),
                        const SizedBox(width: 12),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n['title'] as String,
                                style: _inter(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: isRead ? const Color(0xFF8AAFD4) : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                n['body'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _inter(
                                  size: 12,
                                  color: isRead
                                      ? const Color(0xFF5BB8F5).withValues(alpha: 0.6)
                                      : const Color(0xFF8AAFD4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                n['time'] as String,
                                style: _inter(
                                  size: 10,
                                  color: const Color(0xFF5BB8F5).withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right side
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0C040),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            else
                              const SizedBox(height: 8),
                            const SizedBox(height: 16),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: const Color(0xFF5BB8F5).withValues(alpha: 0.4),
                            ),
                          ],
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
          const Icon(Icons.notifications_off_rounded, size: 64, color: Color(0xFF1A3A5C)),
          const SizedBox(height: 16),
          Text('No notifications', style: _inter(size: 16, weight: FontWeight.w600, color: const Color(0xFF5BB8F5))),
          const SizedBox(height: 6),
          Text(
            'You are all caught up!',
            style: _inter(size: 13, color: const Color(0xFF5BB8F5).withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
