import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';

class QrCardScreen extends StatefulWidget {
  /// Destination stop selected by the passenger in the search screen.
  /// When provided, the QR encodes JSON with token + stop so the scanner
  /// can send alighting_stop_id to the backend at boarding.
  final String? alightingStopId;
  final String? alightingStopName;

  const QrCardScreen({
    super.key,
    this.alightingStopId,
    this.alightingStopName,
  });

  @override
  State<QrCardScreen> createState() => _QrCardScreenState();
}

class _QrCardScreenState extends State<QrCardScreen> {
  static const _bg   = Color(0xFF040A14);
  static const _card = Color(0xFF0A1628);
  static const _cyan = Color(0xFF4ECDC4);

  String?   _qrToken;
  String?   _qrData;  // what the QR actually encodes (JSON or raw token)
  DateTime? _expiresAt;
  bool      _isLoading  = true;
  String?   _error;
  int       _secondsLeft = 0;
  Timer?    _countdownTimer;

  // Use destination from constructor OR from route extras
  String? get _stopId   => widget.alightingStopId;
  String? get _stopName => widget.alightingStopName;

  @override
  void initState() {
    super.initState();
    _loadQrCard();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Build the QR data string.
  /// If the passenger selected a destination stop: encode as JSON.
  /// Otherwise: encode just the token (backward compatible with old scanner).
  String _buildQrData(String token) {
    if (_stopId != null && _stopId!.isNotEmpty) {
      return jsonEncode({
        't': token,
        's': _stopId,
        if (_stopName != null) 'n': _stopName,
      });
    }
    return token;
  }

  Future<void> _loadQrCard() async {
    await _fetchQrCard(force: false);
  }

  // Called by the refresh button — always generates a brand-new token
  Future<void> _refreshQrCard() async {
    await _fetchQrCard(force: true);
  }

  Future<void> _fetchQrCard({required bool force}) async {
    setState(() { _isLoading = true; _error = null; });
    final auth  = context.read<AuthProvider>();
    final token = await auth.getAccessToken();
    if (token == null) {
      setState(() { _error = 'Not logged in'; _isLoading = false; }); return;
    }
    try {
      // force=true → refresh button pressed → always get a new token
      // force=false → screen load or auto-refresh → only new token if expired
      final uri = Uri.parse('$kBaseUrlDev/qr/my-card')
          .replace(queryParameters: force ? {'force': 'true'} : {});
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        final data      = body['data'] as Map<String, dynamic>;
        final qrToken   = data['qr_token']    as String;
        final expiresAt = DateTime.parse(data['qr_expires_at'] as String).toLocal();
        if (mounted) context.read<UserProvider>().updateQrToken(qrToken);
        setState(() {
          _qrToken    = qrToken;
          _qrData     = _buildQrData(qrToken);
          _expiresAt  = expiresAt;
          _isLoading  = false;
        });
        _startCountdown();
      } else {
        setState(() { _error = body['message'] ?? 'Failed to load QR card'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error. Is the backend running?'; _isLoading = false; });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_expiresAt == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final remaining = _expiresAt!.difference(DateTime.now()).inSeconds;
      setState(() => _secondsLeft = remaining.clamp(0, 9999));
      if (remaining <= 0) { timer.cancel(); _loadQrCard(); }
    });
    setState(() => _secondsLeft = _expiresAt!.difference(DateTime.now()).inSeconds.clamp(0, 9999));
  }

  String get _countdownText {
    if (_secondsLeft <= 0) return 'Refreshing...';
    final m = _secondsLeft ~/ 60, s = _secondsLeft % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')} min' : '${_secondsLeft}s';
  }

  Color get _countdownColor =>
      _secondsLeft <= 30 ? AppColors.danger
      : _secondsLeft <= 60 ? AppColors.warning
      : AppColors.success;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer<UserProvider>(builder: (context, userProvider, _) {
          final user = userProvider.user;
          if (user == null) return const Center(child: CircularProgressIndicator());

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [

              // ── Header ───────────────────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back,
                          size: 14, color: Colors.white70))),
                  const SizedBox(width: 8),
                  const Text('My QR Card',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
                GestureDetector(
                  onTap: _refreshQrCard,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.refresh_rounded,
                        size: 18, color: Colors.white70))),
              ]),
              const SizedBox(height: 16),

              // ── FR-34: Destination badge (shown if stop selected) ─────────
              if (_stopName != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF065F46).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF059669).withOpacity(0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_on_rounded,
                        size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DESTINATION',
                            style: TextStyle(fontSize: 10,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 2),
                        Text(_stopName!,
                            style: const TextStyle(fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Text('ENCODED IN QR',
                          style: TextStyle(fontSize: 9,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // ── QR Card ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.8, -0.6),
                    end:   const Alignment(0.8, 0.6),
                    colors: [_card, _cyan.withOpacity(0.3)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                      color: _cyan.withOpacity(0.15),
                      blurRadius: 24, offset: const Offset(0, 8))]),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('BUSGO',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 1)),
                      Text('PASSENGER CARD',
                          style: TextStyle(fontSize: 9,
                              color: _cyan.withOpacity(0.7), letterSpacing: 1)),
                    ]),
                    const Text('🚌', style: TextStyle(fontSize: 24)),
                  ]),
                  const SizedBox(height: 16),

                  // QR code container
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      if (_isLoading)
                        const SizedBox(height: 160, width: 160,
                            child: Center(child: CircularProgressIndicator()))
                      else if (_error != null)
                        SizedBox(height: 160, width: 160,
                            child: Center(child: Column(
                                mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.danger, size: 32),
                              const SizedBox(height: 8),
                              Text('Failed to load',
                                  style: TextStyle(fontSize: 11,
                                      color: AppColors.danger),
                                  textAlign: TextAlign.center),
                            ])))
                      else if (_qrData != null)
                        QrImageView(
                          data:        _qrData!,
                          version:     QrVersions.auto,
                          size:        160,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square, color: Colors.black),
                          dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black)),
                      const SizedBox(height: 6),
                      if (!_isLoading && _error == null)
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.timer_outlined, size: 12, color: _countdownColor),
                          const SizedBox(width: 4),
                          Text('Refreshes in $_countdownText',
                              style: TextStyle(fontSize: 11,
                                  color: _countdownColor,
                                  fontWeight: FontWeight.w600)),
                        ]),
                    ])),
                  const SizedBox(height: 14),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('PASSENGER',
                          style: TextStyle(fontSize: 11,
                              color: _cyan.withOpacity(0.7))),
                      const SizedBox(height: 2),
                      Text(user.fullName,
                          style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('@${user.username}',
                          style: TextStyle(fontSize: 10,
                              color: _cyan.withOpacity(0.7))),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('VALID UNTIL',
                          style: TextStyle(fontSize: 11,
                              color: _cyan.withOpacity(0.7))),
                      const SizedBox(height: 2),
                      Text(user.validUntil,
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(user.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: const TextStyle(fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white))),
                    ]),
                  ]),
                ])),
              const SizedBox(height: 16),

              // ── Security banner ───────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _cyan.withOpacity(0.2))),
                child: Row(children: [
                  Icon(Icons.security_rounded, size: 16, color: _cyan),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'QR refreshes every 5 minutes for security. One-time use per boarding.',
                    style: TextStyle(fontSize: 11,
                        color: _cyan.withOpacity(0.8), height: 1.4))),
                ])),
              const SizedBox(height: 12),

              // ── Change destination ────────────────────────────────────────
              if (_stopName != null)
                TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                  label: const Text('Change Destination'),
                  style: TextButton.styleFrom(
                    foregroundColor: _cyan.withOpacity(0.7)),
                ),

              const SizedBox(height: 10),
              Text(
                'Show this QR when boarding and again when exiting.\n'
                'After exit scan, you\'ll be asked to rate your trip.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10,
                    color: Colors.white.withOpacity(0.3), height: 1.5)),
              const SizedBox(height: 20),
            ]),
          );
        }),
      ),
    );
  }
}




