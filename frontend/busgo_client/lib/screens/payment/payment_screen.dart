import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/busgo_alert.dart';
import '../../widgets/payment_processing_overlay.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _baseUrl = 'http://192.168.126.1:5000';

  List<dynamic> _routes = [];
  List<dynamic> _stops = [];
  List<dynamic> _myTickets = [];
  bool _loadingRoutes = true;
  bool _loadingStops = false;

  Map<String, dynamic>? _selectedRoute;
  Map<String, dynamic>? _boardingStop;
  Map<String, dynamic>? _alightingStop;
  Map<String, dynamic>? _fareResult;
  Map<String, dynamic>? _activeTicket;

  int _tab = 0; // 0=Buy, 1=Tickets

  String get _token => context.read<AuthProvider>().accessToken ?? '';
  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _loadMyTickets();
  }

  Future<void> _loadRoutes() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/payments/routes'), headers: _headers);
      final body = jsonDecode(res.body);
      setState(() { _routes = body['data'] ?? []; _loadingRoutes = false; });
    } catch (e) {
      setState(() => _loadingRoutes = false);
    }
  }

  Future<void> _loadStops(String routeId) async {
    setState(() { _loadingStops = true; _stops = []; _boardingStop = null; _alightingStop = null; _fareResult = null; });
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/payments/route/$routeId/stops'), headers: _headers);
      final body = jsonDecode(res.body);
      setState(() { _stops = body['data'] ?? []; _loadingStops = false; });
    } catch (e) {
      setState(() => _loadingStops = false);
    }
  }

  Future<void> _calculateFare() async {
    if (_selectedRoute == null || _boardingStop == null || _alightingStop == null) return;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/payments/calculate?route_id=${_selectedRoute!['id']}&from_stop=${_boardingStop!['id']}&to_stop=${_alightingStop!['id']}'),
        headers: _headers,
      );
      setState(() => _fareResult = jsonDecode(res.body)['data']);
    } catch (_) {}
  }

  Future<void> _initiatePayment() async {
    if (_fareResult == null) return;

    // Show processing overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PaymentProcessingOverlay(),
    );

    // Simulate processing time for demo
    await Future.delayed(const Duration(seconds: 4));

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/payments/initiate'),
        headers: _headers,
        body: jsonEncode({
          'route_id': _selectedRoute!['id'],
          'boarding_stop_id': _boardingStop!['id'],
          'alighting_stop_id': _alightingStop!['id'],
        }),
      );

      final body = jsonDecode(res.body);

      // Close processing overlay
      if (mounted) Navigator.of(context).pop();

      if (body['success'] == true) {
        final data = body['data'];

        if (data['is_sandbox'] == true) {
          // Sandbox mode: ticket is already paid
          setState(() {
            _activeTicket = data['ticket'];
            _tab = 1;
          });
          _loadMyTickets();
          if (mounted) {
            BusgoAlert.show(context,
              type: BusgoAlertType.success,
              title: 'Payment Successful!',
              message: 'Your ticket for LKR ${data['amount']} has been generated.',
            );
          }
        } else {
          // Live mode: redirect to WEBXPAY
          // TODO: Open WEBXPAY payment page in webview
          if (mounted) {
            BusgoAlert.show(context,
              type: BusgoAlertType.info,
              title: 'Redirecting...',
              message: 'Opening payment gateway...',
            );
          }
        }
      } else {
        if (mounted) {
          BusgoAlert.show(context,
            type: BusgoAlertType.error,
            title: 'Payment Failed',
            message: body['message'] ?? 'Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        BusgoAlert.show(context,
          type: BusgoAlertType.error,
          title: 'Connection Error',
          message: 'Could not reach payment server.',
        );
      }
    }
  }

  Future<void> _loadMyTickets() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/payments/my-tickets'), headers: _headers);
      setState(() => _myTickets = jsonDecode(res.body)['data'] ?? []);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040A14),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text('Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: AppColors.primary,
            child: Row(children: [_buildTab('Buy Ticket', 0), _buildTab('My Tickets', 1)]),
          ),
          Expanded(child: _tab == 0 ? _buildBuyTab() : _buildTicketsTab()),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? Colors.white : Colors.transparent, width: 3)),
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: active ? Colors.white : Colors.white54, fontWeight: active ? FontWeight.w600 : FontWeight.w400, fontSize: 14)),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUY TAB — Checkout form (Codepen inspired)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBuyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Checkout card (white, rounded, shadow) ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_bus_rounded, size: 20, color: AppColors.secondary),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BUSGO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1)),
                        Text('Ticket Checkout', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('SANDBOX', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF16A34A), letterSpacing: 0.5)),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(color: Color(0xFFF0F0F0)),
                const SizedBox(height: 16),

                // Step 1: Route
                _buildFieldLabel('SELECT ROUTE', 'Choose your bus route'),
                const SizedBox(height: 8),
                _buildRouteSelector(),

                if (_selectedRoute != null) ...[
                  const SizedBox(height: 20),
                  // Step 2: Boarding
                  _buildFieldLabel('BOARDING STOP', 'Where are you getting on?'),
                  const SizedBox(height: 8),
                  _loadingStops
                      ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
                      : _buildStopSelector(
                          value: _boardingStop,
                          hint: 'Select boarding stop',
                          onChanged: (s) { setState(() { _boardingStop = s; _fareResult = null; }); if (_alightingStop != null) _calculateFare(); },
                        ),
                ],

                if (_boardingStop != null) ...[
                  const SizedBox(height: 20),
                  // Step 3: Destination
                  _buildFieldLabel('DESTINATION STOP', 'Where are you getting off?'),
                  const SizedBox(height: 8),
                  _buildStopSelector(
                    value: _alightingStop,
                    hint: 'Select destination stop',
                    exclude: _boardingStop?['id'],
                    onChanged: (s) { setState(() => _alightingStop = s); _calculateFare(); },
                  ),
                ],
              ],
            ),
          ),

          // ── Fare summary + pay button ──
          if (_fareResult != null) ...[
            const SizedBox(height: 16),
            _buildFareSummary(),
            const SizedBox(height: 16),
            _buildPayButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteSelector() {
    if (_loadingRoutes) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF1A1E2E),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          isExpanded: true,
          value: _selectedRoute,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          hint: const Text('Choose a route...', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
          items: _routes.map<DropdownMenuItem<Map<String, dynamic>>>((r) {
            final route = r as Map<String, dynamic>;
            return DropdownMenuItem(
              value: route,
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: _parseColor(route['color']), borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text(route['route_number'] ?? '', style: const TextStyle(color: const Color(0xFF0A1628), fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${route['origin']} → ${route['destination']}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                ],
              ),
            );
          }).toList(),
          onChanged: (route) {
            setState(() { _selectedRoute = route; _boardingStop = null; _alightingStop = null; _fareResult = null; });
            if (route != null) _loadStops(route['id']);
          },
        ),
      ),
    );
  }

  Widget _buildStopSelector({
    Map<String, dynamic>? value,
    required String hint,
    String? exclude,
    required ValueChanged<Map<String, dynamic>?> onChanged,
  }) {
    final filtered = exclude != null ? _stops.where((s) => s['id'] != exclude).toList() : _stops;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF1A1E2E),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          isExpanded: true,
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          hint: Text(hint, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
          items: filtered.map<DropdownMenuItem<Map<String, dynamic>>>((s) {
            final stop = s as Map<String, dynamic>;
            return DropdownMenuItem(
              value: stop,
              child: Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    alignment: Alignment.center,
                    child: Text('${stop['stop_order']}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(stop['stop_name'] ?? '', style: const TextStyle(fontSize: 13))),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFareSummary() {
    final fare = _fareResult!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1A2E), Color(0xFF132F54), Color(0xFF1565C0)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('LKR ', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w400)),
              Text('${fare['amount']?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(color: const Color(0xFF0A1628), fontSize: 40, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),

          // Route visual
          Row(
            children: [
              Column(
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                  Container(width: 2, height: 30, color: Colors.white.withOpacity(0.2)),
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_boardingStop?['stop_name'] ?? '', style: const TextStyle(color: const Color(0xFF0A1628), fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 18),
                    Text(_alightingStop?['stop_name'] ?? '', style: const TextStyle(color: const Color(0xFF0A1628), fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 8),

          // Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _fareDetail('Stops', '${fare['stop_count']}'),
              _fareDetail('Base', 'LKR ${fare['base_fare']}'),
              _fareDetail('Per stop', 'LKR ${fare['per_stop']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fareDetail(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: const Color(0xFF0A1628), fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
      ],
    );
  }

  Widget _buildPayButton() {
    return GestureDetector(
      onTap: _initiatePayment,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF22C55E)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: const Color(0xFF0A1628), size: 18),
            const SizedBox(width: 8),
            Text('Pay LKR ${_fareResult?['amount']?.toStringAsFixed(2) ?? '0'} Securely',
              style: const TextStyle(color: const Color(0xFF0A1628), fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TICKETS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTicketsTab() {
    if (_activeTicket != null) return _buildTicketDetail(_activeTicket!);

    if (_myTickets.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.confirmation_number_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('No tickets yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
          const SizedBox(height: 4),
          const Text('Buy a ticket to see it here', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTickets.length,
        itemBuilder: (context, index) {
          final ticket = _myTickets[index] as Map<String, dynamic>;
          final isPaid = ticket['payment_status'] == 'paid';
          final routeData = ticket['bus_routes'];
          return GestureDetector(
            onTap: () => setState(() => _activeTicket = ticket),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isPaid ? const Color(0xFF22C55E).withOpacity(0.3) : const Color(0xFFEEEEEE)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: _parseColor(routeData?['color']), borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(routeData?['route_number'] ?? '?', style: const TextStyle(color: const Color(0xFF0A1628), fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${ticket['boarding_stop_name']} → ${ticket['alighting_stop_name']}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('LKR ${ticket['amount']} · ${ticket['stop_count']} stops', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(isPaid ? 'PAID' : 'PENDING',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFF59E0B))),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTicketDetail(Map<String, dynamic> ticket) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Back
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => setState(() => _activeTicket = null),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_ios, size: 14, color: AppColors.textMuted),
              SizedBox(width: 4),
              Text('Back to tickets', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Ticket card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1628),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: ticket['payment_status'] == 'paid' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ticket['payment_status'] == 'paid' ? '✅ PAID — VALID' : '⏳ PENDING',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: ticket['payment_status'] == 'paid' ? const Color(0xFF16A34A) : const Color(0xFFF59E0B)),
              ),
            ),
            const SizedBox(height: 24),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
              ),
              child: QrImageView(data: ticket['qr_data'] ?? '', version: QrVersions.auto, size: 180, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 16),

            // Verification code
            const Text('VERIFICATION CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(ticket['verification_code'] ?? '',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 10)),
            const SizedBox(height: 20),

            const Divider(color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            _ticketRow('Route', ticket['bus_routes']?['route_number'] ?? '?'),
            _ticketRow('From', ticket['boarding_stop_name'] ?? ''),
            _ticketRow('To', ticket['alighting_stop_name'] ?? ''),
            _ticketRow('Stops', '${ticket['stop_count']}'),
            _ticketRow('Amount', 'LKR ${ticket['amount']}'),
            _ticketRow('Valid Until', _formatDate(ticket['valid_until'])),
          ]),
        ),

        const SizedBox(height: 16),
        Text('Show this QR code to the scanner when boarding',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ]),
    );
  }

  Widget _ticketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'N/A';
    try { final dt = DateTime.parse(iso); return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'; }
    catch (_) { return iso; }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppColors.secondary;
    try { return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16)); }
    catch (_) { return AppColors.secondary; }
  }
}





