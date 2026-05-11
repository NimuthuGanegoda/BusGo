import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/busgo_alert.dart';
import '../../widgets/payment_processing_overlay.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static String get _baseUrl => (dotenv.env['API_URL'] ?? 'http://192.168.1.3:5000/api').replaceAll('/api', '');

  List<dynamic> _routes    = [];
  List<dynamic> _stops     = [];
  List<dynamic> _myTickets = [];
  bool _loadingRoutes  = true;
  bool _loadingStops   = false;
  bool _loadingTickets = true;

  Map<String, dynamic>? _selectedRoute;
  Map<String, dynamic>? _boardingStop;
  Map<String, dynamic>? _alightingStop;
  Map<String, dynamic>? _fareResult;
  Map<String, dynamic>? _activeTicket;

  int _tab = 0;

  // ── Payment details state ─────────────────────────────────────────────────
  bool _showingPaymentDetails = false;
  final _cardNameCtrl    = TextEditingController();
  final _cardNumberCtrl  = TextEditingController();
  final _expiryCtrl      = TextEditingController();
  final _cvvCtrl         = TextEditingController();
  final _address1Ctrl    = TextEditingController();
  final _address2Ctrl    = TextEditingController();
  final _cityCtrl        = TextEditingController();
  final _zipCtrl         = TextEditingController();
  final _detailsFormKey  = GlobalKey<FormState>();
  bool _obscureCvv = true;

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

  @override
  void dispose() {
    _cardNameCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _cityCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    try {
      final res  = await http.get(Uri.parse('$_baseUrl/api/payments/routes'), headers: _headers);
      final body = jsonDecode(res.body);
      if (mounted) setState(() { _routes = body['data'] ?? []; _loadingRoutes = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  Future<void> _loadStops(String routeId) async {
    if (mounted) setState(() { _loadingStops = true; _stops = []; _boardingStop = null; _alightingStop = null; _fareResult = null; });
    try {
      final res  = await http.get(Uri.parse('$_baseUrl/api/payments/route/$routeId/stops'), headers: _headers);
      final body = jsonDecode(res.body);
      if (mounted) setState(() { _stops = body['data'] ?? []; _loadingStops = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingStops = false);
    }
  }

  Future<void> _calculateFare() async {
    if (_selectedRoute == null || _boardingStop == null || _alightingStop == null) return;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/payments/calculate?route_id=${_selectedRoute!['id']}&from_stop=${_boardingStop!['id']}&to_stop=${_alightingStop!['id']}'),
        headers: _headers,
      );
      if (mounted) setState(() => _fareResult = jsonDecode(res.body)['data']);
    } catch (_) {}
  }

  Future<void> _initiatePayment() async {
    if (_fareResult == null) return;
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const PaymentProcessingOverlay());
    await Future.delayed(const Duration(seconds: 4));
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/payments/initiate'),
        headers: _headers,
        body: jsonEncode({
          'route_id':          _selectedRoute!['id'],
          'boarding_stop_id':  _boardingStop!['id'],
          'alighting_stop_id': _alightingStop!['id'],
        }),
      );
      final body = jsonDecode(res.body);
      if (mounted) Navigator.of(context).pop();
      if (body['success'] == true) {
        final data = body['data'];
        if (data['is_sandbox'] == true) {
          if (mounted) setState(() { _activeTicket = data['ticket']; _tab = 1; _showingPaymentDetails = false; });
          _loadMyTickets();
          if (mounted) BusgoAlert.show(context, type: BusgoAlertType.success,
              title: 'Payment Successful!',
              message: 'Your ticket for LKR ${data['amount']} has been generated.');
        } else {
          if (mounted) BusgoAlert.show(context, type: BusgoAlertType.info,
              title: 'Redirecting...', message: 'Opening payment gateway...');
        }
      } else {
        if (mounted) BusgoAlert.show(context, type: BusgoAlertType.error,
            title: 'Payment Failed', message: body['message'] ?? 'Please try again.');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) BusgoAlert.show(context, type: BusgoAlertType.error,
          title: 'Connection Error', message: 'Could not reach payment server.');
    }
  }

  Future<void> _loadMyTickets() async {
    if (mounted) setState(() => _loadingTickets = true);
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/payments/my-tickets'), headers: _headers);
      if (mounted) setState(() {
        _myTickets     = jsonDecode(res.body)['data'] ?? [];
        _loadingTickets = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040A14),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () {
            if (_showingPaymentDetails) {
              setState(() => _showingPaymentDetails = false);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _showingPaymentDetails ? 'Payment Details' : 'Payment',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        if (!_showingPaymentDetails)
          Container(
            color: AppColors.primary,
            child: Row(children: [_buildTab('Buy Ticket', 0), _buildTab('My Tickets', 1)]),
          ),
        Expanded(child: _showingPaymentDetails
            ? _buildPaymentDetailsForm()
            : _tab == 0 ? _buildBuyTab() : _buildTicketsTab()),
      ]),
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
            border: Border(bottom: BorderSide(
                color: active ? Colors.white : Colors.transparent, width: 3))),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14)),
        ),
      ),
    );
  }

  // ── BUY TAB ───────────────────────────────────────────────────────────────
  Widget _buildBuyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1628),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 20, offset: const Offset(0, 4))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.directions_bus_rounded, size: 20, color: AppColors.secondary)),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('BUSGO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 1)),
                Text('Ticket Checkout', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
                child: const Text('SANDBOX', style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w700, color: Color(0xFF16A34A), letterSpacing: 0.5))),
            ]),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),

            _buildFieldLabel('SELECT ROUTE', 'Choose your bus route'),
            const SizedBox(height: 8),
            _buildRouteSelector(),

            if (_selectedRoute != null) ...[
              const SizedBox(height: 20),
              _buildFieldLabel('BOARDING STOP', 'Where are you getting on?'),
              const SizedBox(height: 8),
              _loadingStops
                  ? const Center(child: Padding(padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary)))
                  : _buildStopSelector(
                      value: _boardingStop,
                      hint: 'Select boarding stop',
                      onChanged: (s) {
                        setState(() { _boardingStop = s; _fareResult = null; });
                        if (_alightingStop != null) _calculateFare();
                      }),
            ],

            if (_boardingStop != null) ...[
              const SizedBox(height: 20),
              _buildFieldLabel('DESTINATION STOP', 'Where are you getting off?'),
              const SizedBox(height: 8),
              _buildStopSelector(
                value: _alightingStop,
                hint: 'Select destination stop',
                exclude: _boardingStop?['id'],
                onChanged: (s) { setState(() => _alightingStop = s); _calculateFare(); }),
            ],
          ]),
        ),

        if (_fareResult != null) ...[
          const SizedBox(height: 16),
          _buildFareSummary(),
          const SizedBox(height: 16),
          _buildPayButton(),
        ],
      ]),
    );
  }

  Widget _buildFieldLabel(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.secondary, letterSpacing: 0.8)),
      const SizedBox(height: 2),
      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45))),
    ]);
  }

  Widget _buildRouteSelector() {
    if (_loadingRoutes) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF0D1F35)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          isExpanded: true,
          value: _selectedRoute,
          dropdownColor: const Color(0xFF0D1F35),
          iconEnabledColor: Colors.white54,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          hint: const Text('Choose a route...',
              style: TextStyle(fontSize: 14, color: Colors.white54)),
          items: _routes.map<DropdownMenuItem<Map<String, dynamic>>>((r) {
            final route = r as Map<String, dynamic>;
            return DropdownMenuItem(
              value: route,
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _parseColor(route['color']),
                    borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Text(route['route_number'] ?? '',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  '${route['origin']} \u2192 ${route['destination']}',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis)),
              ]),
            );
          }).toList(),
          onChanged: (route) {
            setState(() { _selectedRoute = route; _boardingStop = null;
                          _alightingStop = null; _fareResult = null; });
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
    final filtered = exclude != null
        ? _stops.where((s) => s['id'] != exclude).toList()
        : _stops;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF0D1F35)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          isExpanded: true,
          value: value,
          dropdownColor: const Color(0xFF0D1F35),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          hint: Text(hint, style: const TextStyle(fontSize: 14, color: Colors.white54)),
          items: filtered.map<DropdownMenuItem<Map<String, dynamic>>>((s) {
            final stop = s as Map<String, dynamic>;
            return DropdownMenuItem(
              value: stop,
              child: Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6)),
                  alignment: Alignment.center,
                  child: Text('${stop['stop_order']}',
                      style: const TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w700, color: AppColors.secondary))),
                const SizedBox(width: 10),
                Expanded(child: Text(stop['stop_name'] ?? '',
                    style: const TextStyle(fontSize: 13, color: Colors.white))),
              ]),
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
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('LKR ', style: TextStyle(color: Colors.white.withOpacity(0.6),
              fontSize: 16, fontWeight: FontWeight.w400)),
          Text('${fare['amount']?.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(color: Colors.white,
                  fontSize: 40, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Column(children: [
            Container(width: 10, height: 10,
                decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
            Container(width: 2, height: 30, color: Colors.white.withOpacity(0.2)),
            Container(width: 10, height: 10,
                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_boardingStop?['stop_name'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 18),
            Text(_alightingStop?['stop_name'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ])),
        ]),
        const SizedBox(height: 14),
        Divider(color: Colors.white.withOpacity(0.15)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _fareDetail('Stops',    '${fare['stop_count']}'),
          _fareDetail('Base',     'LKR ${fare['base_fare']}'),
          _fareDetail('Per stop', 'LKR ${fare['per_stop']}'),
        ]),
      ]),
    );
  }

  Widget _fareDetail(String label, String value) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white,
        fontSize: 14, fontWeight: FontWeight.w600)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
  ]);

  Widget _buildPayButton() {
    return GestureDetector(
      onTap: () => setState(() => _showingPaymentDetails = true),
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF22C55E)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.35),
              blurRadius: 16, offset: const Offset(0, 6))]),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Pay LKR ${_fareResult?['amount']?.toStringAsFixed(2) ?? '0'} Securely',
              style: const TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ── PAYMENT DETAILS FORM ──────────────────────────────────────────────────
  Widget _buildPaymentDetailsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _detailsFormKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Amount summary banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF22C55E), size: 20),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_boardingStop?['stop_name']} \u2192 ${_alightingStop?['stop_name']}',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                const SizedBox(height: 2),
                Text('LKR ${_fareResult?['amount']?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        color: Color(0xFF22C55E))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('SANDBOX', style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w700, color: Color(0xFF16A34A)))),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Card Information ──────────────────────────────────────────────
          _sectionHeader(Icons.credit_card_rounded, 'Card Information'),
          const SizedBox(height: 12),

          _paymentField(
            controller: _cardNameCtrl,
            label: 'Cardholder Name',
            hint: 'e.g. Nimal Perera',
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),

          _paymentField(
            controller: _cardNumberCtrl,
            label: 'Card Number',
            hint: '0000  0000  0000  0000',
            icon: Icons.credit_card_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberFormatter(),
            ],
            validator: (v) {
              final digits = v?.replaceAll(' ', '') ?? '';
              if (digits.length != 16) return 'Enter a valid 16-digit card number';
              return null;
            },
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: _paymentField(
              controller: _expiryCtrl,
              label: 'Expiry Date',
              hint: 'MM/YY',
              icon: Icons.calendar_today_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ExpiryFormatter(),
              ],
              validator: (v) {
                if (v == null || v.length < 5) return 'Invalid expiry';
                return null;
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: StatefulBuilder(builder: (ctx, setS) => _paymentField(
              controller: _cvvCtrl,
              label: 'CVV / CVC',
              hint: '•••',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscureCvv,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              suffixIcon: IconButton(
                icon: Icon(_obscureCvv ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 16, color: Colors.white38),
                onPressed: () => setState(() => _obscureCvv = !_obscureCvv),
              ),
              validator: (v) {
                if (v == null || v.length < 3) return 'Invalid CVV';
                return null;
              },
            ))),
          ]),

          const SizedBox(height: 20),

          // ── Billing Address ───────────────────────────────────────────────
          _sectionHeader(Icons.location_on_outlined, 'Billing Address'),
          const SizedBox(height: 12),

          _paymentField(
            controller: _address1Ctrl,
            label: 'Address Line 1',
            hint: 'Street address',
            icon: Icons.home_outlined,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
          ),
          const SizedBox(height: 12),

          _paymentField(
            controller: _address2Ctrl,
            label: 'Address Line 2 (optional)',
            hint: 'Apartment, suite, etc.',
            icon: Icons.apartment_rounded,
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: _paymentField(
              controller: _cityCtrl,
              label: 'City',
              hint: 'Colombo',
              icon: Icons.location_city_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'City required' : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: _paymentField(
              controller: _zipCtrl,
              label: 'Zip / Postal Code',
              hint: '00100',
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Zip required' : null,
            )),
          ]),

          const SizedBox(height: 28),

          // Security note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: Row(children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF22C55E)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Your payment is processed securely. Card details are not stored.',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5), height: 1.4))),
            ]),
          ),

          const SizedBox(height: 16),

          // Confirm & Pay button
          GestureDetector(
            onTap: () {
              if (_detailsFormKey.currentState!.validate()) {
                _initiatePayment();
              }
            },
            child: Container(
              width: double.infinity, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF22C55E)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF16A34A).withOpacity(0.35),
                    blurRadius: 16, offset: const Offset(0, 6))]),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Confirm & Pay LKR ${_fareResult?['amount']?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 8),

          // Cancel button
          GestureDetector(
            onTap: () => setState(() => _showingPaymentDetails = false),
            child: Container(
              width: double.infinity, height: 44,
              alignment: Alignment.center,
              child: Text('Cancel', style: TextStyle(
                  fontSize: 14, color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.secondary),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.secondary, letterSpacing: 0.5)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
    ]);
  }

  Widget _paymentField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.5), letterSpacing: 0.5)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.25)),
          prefixIcon: Icon(icon, size: 18, color: Colors.white38),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: const Color(0xFF0A1628),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.secondary, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444))),
          errorStyle: const TextStyle(fontSize: 10, color: Color(0xFFEF4444)),
        ),
      ),
    ]);
  }

  // ── TICKETS TAB ───────────────────────────────────────────────────────────
  Widget _buildTicketsTab() {
    if (_activeTicket != null) return _buildTicketDetail(_activeTicket!);
    if (_loadingTickets) return _buildTicketsSkeleton();
    if (_myTickets.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.confirmation_number_outlined, size: 48,
            color: Colors.white.withOpacity(0.2)),
        const SizedBox(height: 12),
        const Text('No tickets yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Buy a ticket to see it here',
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4))),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadMyTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTickets.length,
        itemBuilder: (context, index) {
          final ticket    = _myTickets[index] as Map<String, dynamic>;
          final isPaid    = ticket['payment_status'] == 'paid';
          final routeData = ticket['bus_routes'];
          return GestureDetector(
            onTap: () => setState(() => _activeTicket = ticket),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPaid
                      ? const Color(0xFF22C55E).withOpacity(0.3)
                      : Colors.white.withOpacity(0.08)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
                    blurRadius: 8, offset: const Offset(0, 2))]),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _parseColor(routeData?['color']),
                    borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(routeData?['route_number'] ?? '?',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${ticket['boarding_stop_name']} \u2192 ${ticket['alighting_stop_name']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('LKR ${ticket['amount']} \u00B7 ${ticket['stop_count']} stops',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45))),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFF16A34A).withOpacity(0.15)
                        : const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(isPaid ? 'PAID' : 'PENDING',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: isPaid
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFF59E0B)))),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTicketsSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1628),
          borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 13, width: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(height: 11, width: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4))),
          ])),
        ]),
      ),
    );
  }

  Widget _buildTicketDetail(Map<String, dynamic> ticket) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => setState(() => _activeTicket = null),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_ios, size: 14, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text('Back to tickets',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1628),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
                blurRadius: 24, offset: const Offset(0, 8))]),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: ticket['payment_status'] == 'paid'
                    ? const Color(0xFF16A34A).withOpacity(0.15)
                    : const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
              child: Text(
                ticket['payment_status'] == 'paid' ? '\u2705 PAID \u2013 VALID' : '\u23F3 PENDING',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: ticket['payment_status'] == 'paid'
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFF59E0B)))),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 2)),
              child: QrImageView(
                  data: ticket['qr_data'] ?? '',
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white)),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 12),
            _ticketRow('Route',      ticket['bus_routes']?['route_number'] ?? '?'),
            _ticketRow('From',       ticket['boarding_stop_name'] ?? ''),
            _ticketRow('To',         ticket['alighting_stop_name'] ?? ''),
            _ticketRow('Stops',      '${ticket['stop_count']}'),
            _ticketRow('Amount',     'LKR ${ticket['amount']}'),
            _ticketRow('Valid Until', _formatDate(ticket['valid_until'])),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Show this QR code to the scanner when boarding',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35))),
      ]),
    );
  }

  Widget _ticketRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45))),
      Text(value, style: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.w600, color: Colors.white)),
    ]),
  );

  String _formatDate(String? iso) {
    if (iso == null) return 'N/A';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppColors.secondary;
    try { return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16)); }
    catch (_) { return AppColors.secondary; }
  }
}

// ── Input formatters ──────────────────────────────────────────────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    if (digits.length > 16) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('  ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return TextEditingValue(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length > 4) return oldValue;
    String formatted = digits;
    if (digits.length >= 3) {
      formatted = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
