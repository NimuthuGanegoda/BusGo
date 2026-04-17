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
  const QrCardScreen({super.key});
  @override State<QrCardScreen> createState() => _QrCardScreenState();
}

class _QrCardScreenState extends State<QrCardScreen> {
  String?  _qrToken;
  DateTime? _expiresAt;
  bool     _isLoading  = true;
  String?  _error;
  int      _secondsLeft = 0;
  Timer?   _countdownTimer;
  Timer?   _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadQrCard();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_qrToken != null) {
      _loadQrCard();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  
  // ── Fetch QR card from backend ─────────────────────────────────────────────
  Future<void> _loadQrCard() async {
    setState(() { _isLoading = true; _error = null; });

    final auth  = context.read<AuthProvider>();
    final token = await auth.getAccessToken();

    if (token == null) {
      setState(() { _error = 'Not logged in'; _isLoading = false; });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$kBaseUrlDev/qr/my-card'),
        headers: { 'Authorization': 'Bearer $token' },
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        final data     = body['data'] as Map<String, dynamic>;
        final qrToken  = data['qr_token']    as String;
        final expiryStr = data['qr_expires_at'] as String;
        final expiresAt = DateTime.parse(expiryStr).toLocal();

        // Update user provider with fresh data
        if (mounted) {
          context.read<UserProvider>().updateQrToken(qrToken);
        }

        setState(() {
          _qrToken   = qrToken;
          _expiresAt = expiresAt;
          _isLoading = false;
        });

        _startCountdown();
      } else {
        setState(() {
          _error     = body['message'] ?? 'Failed to load QR card';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error     = 'Connection error. Is the backend running?';
        _isLoading = false;
      });
    }
  }

  // ── Countdown timer ────────────────────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_expiresAt == null) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final remaining = _expiresAt!.difference(DateTime.now()).inSeconds;
      setState(() => _secondsLeft = remaining.clamp(0, 9999));

      // Only refresh once when expired — cancel timer first
      if (remaining <= 0) {
        timer.cancel();
        _loadQrCard();
      }
    });

    setState(() {
      _secondsLeft = _expiresAt!.difference(DateTime.now()).inSeconds.clamp(0, 9999);
    });
  }

  String get _countdownText {
    if (_secondsLeft <= 0) return 'Refreshing...';
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')} min';
    }
    return '${_secondsLeft}s';
  }

  Color get _countdownColor {
    if (_secondsLeft <= 30) return AppColors.danger;
    if (_secondsLeft <= 60) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            final user = userProvider.user;
            if (user == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [

                // ── Header ───────────────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 28, height: 28,
                          decoration: const BoxDecoration(
                              color: AppColors.headerBg, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const Icon(Icons.arrow_back,
                              size: 14, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('My QR Card', style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                    ]),
                    // Manual refresh button
                    GestureDetector(
                      onTap: _loadQrCard,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: AppColors.headerBg,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.refresh_rounded,
                            size: 18, color: AppColors.primary),
                      ),
                    ),
                  ]),
                const SizedBox(height: 16),

                // ── QR Card ───────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment(-0.8, -0.6),
                      end: Alignment(0.8, 0.6),
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Column(children: [
                    // Card header
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BUSGO', style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: 1)),
                            Text('PASSENGER CARD', style: TextStyle(
                                fontSize: 9, color: AppColors.lightBlue,
                                letterSpacing: 1)),
                          ]),
                        Text('🚌', style: TextStyle(fontSize: 24)),
                      ]),
                    const SizedBox(height: 16),

                    // QR Code or loading
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        if (_isLoading)
                          const SizedBox(height: 120, width: 120,
                            child: Center(child: CircularProgressIndicator()))
                        else if (_error != null)
                          SizedBox(height: 120, width: 120,
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
                        else if (_qrToken != null)
                          QrImageView(
                            data: _qrToken!,
                            version: QrVersions.auto,
                            size: 160,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black),
                            dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black),
                          ),
                        const SizedBox(height: 6),

                        // Countdown timer
                        if (!_isLoading && _error == null)
                          Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            Icon(Icons.timer_outlined,
                                size: 12, color: _countdownColor),
                            const SizedBox(width: 4),
                            Text('Refreshes in $_countdownText',
                                style: TextStyle(fontSize: 11,
                                    color: _countdownColor,
                                    fontWeight: FontWeight.w600)),
                          ]),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Passenger info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          const Text('PASSENGER', style: TextStyle(
                              fontSize: 11, color: AppColors.lightBlue)),
                          const SizedBox(height: 2),
                          Text(user.fullName, style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                          Text('@${user.username}', style: const TextStyle(
                              fontSize: 10, color: AppColors.lightBlue)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                          const Text('VALID UNTIL', style: TextStyle(
                              fontSize: 11, color: AppColors.lightBlue)),
                          const SizedBox(height: 2),
                          Text(user.validUntil, style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: Colors.white)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              user.isActive ? 'ACTIVE' : 'INACTIVE',
                              style: const TextStyle(fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          ),
                        ]),
                      ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Security info banner ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.security_rounded,
                        size: 16, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'QR refreshes every 5 minutes for security. '
                      'One-time use per boarding.',
                      style: TextStyle(fontSize: 11,
                          color: AppColors.secondary.withValues(alpha: 0.8),
                          height: 1.4),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── Scan to Exit button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: () => context.push('/rating'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5AA8),
                      foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Scan to Exit Bus', style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                      ]),
                  )),
                const SizedBox(height: 10),

                // ── Instructions ──────────────────────────────────────────────
                const Text(
                  'Show this QR when boarding and again when exiting.\n'
                  'After exit scan, you\'ll be asked to rate your trip.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10,
                      color: AppColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 20),
              ]),
            );
          },
        ),
      ),
    );
  }
}