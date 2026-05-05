import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants/app_colors.dart';
import '../services/scanner_api_service.dart';
import 'scan_success_screen.dart';
import 'scan_error_screen.dart';

class ActiveScannerScreen extends StatefulWidget {
  final ScannerApiService api;
  const ActiveScannerScreen({super.key, required this.api});
  @override
  State<ActiveScannerScreen> createState() => _ActiveScannerScreenState();
}

class _ActiveScannerScreenState extends State<ActiveScannerScreen>
    with TickerProviderStateMixin {

  final MobileScannerController _cameraCtrl = MobileScannerController();

  bool      _isScanning = false;
  int       _scanCount  = 0;

  // UFR_48: retry tracking per token
  // token â†’ retry count for system errors only
  static const int _maxRetries = 5;
  final Map<String, int> _retryCount = {};

  // Tracks last scan per token for auto boarding/alighting:
  // token â†’ 'boarding' or 'alighting'
  final Map<String, String> _tokenScanHistory = {};

  Timer?    _debounceTimer;
  String?   _lastScannedValue;
  DateTime? _lastScanTime;

  late AnimationController _scanLineCtrl;
  late Animation<double>   _scanLineAnim;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _glowCtrl;

  static const _cyan = Color(0xFF3FEFEF);

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000))
      ..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _cameraCtrl.dispose();
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _restartCamera() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    try { await _cameraCtrl.start(); } catch (_) {}
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isScanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    final scannedToken = barcode!.rawValue!;
    final now = DateTime.now();
    if (_lastScannedValue == scannedToken && _lastScanTime != null &&
        now.difference(_lastScanTime!).inSeconds < 2) return;
    _lastScannedValue = scannedToken;
    _lastScanTime     = now;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _processScan(scannedToken);
    });
  }

  // â”€â”€ UFR_48: Check if error is a system error (5xx / network) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _isSystemError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('500') ||
          lower.contains('502') ||
          lower.contains('503') ||
          lower.contains('504') ||
          lower.contains('timeout') ||
          lower.contains('socketexception') ||
          lower.contains('connection refused') ||
          lower.contains('network') ||
          lower.contains('future not completed');
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // AUTO BOARDING / ALIGHTING DETECTION
  //
  // UFR_48: On system error (5xx/network), allow up to 5 retries.
  //         On business logic error (4xx), reject immediately â€” no retry.
  //         Same logic applies for both Normal QR and Payment QR.
  // UFR_51: Repeated scan logging is handled server-side in qr.service.js
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Future<void> _processScan(String scannedToken) async {
    if (_isScanning) return;

    final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    final isJsonPayload = scannedToken.trim().startsWith('{');
    if (!uuidPattern.hasMatch(scannedToken) && !isJsonPayload) {
      await _navigateError(
          'Invalid QR code format.\nPlease ask the passenger to show their BUSGO card.');
      return;
    }

    setState(() => _isScanning = true);
    await _cameraCtrl.stop();

    final previousScan = _tokenScanHistory[scannedToken];
    final isExit       = previousScan == 'boarding';

    try {
      final ScanResult result;
      if (isExit) {
        result = await widget.api.scanExit(scannedToken);
        _tokenScanHistory.remove(scannedToken);
      } else {
        result = await widget.api.scanIn(scannedToken);
        _tokenScanHistory[scannedToken] = 'boarding';
      }

      // Success â€” reset retry counter for this token
      _retryCount.remove(scannedToken);

      setState(() { _scanCount++; });
      if (!mounted) return;

      await Navigator.push<bool>(context,
          MaterialPageRoute(builder: (_) => ScanSuccessScreen(result: result)));

      if (mounted) {
        setState(() { _isScanning = false; _lastScannedValue = null; });
        await _restartCamera();
      }
    } catch (e) {
      // Parse structured exception: "statusCode::message"
      final raw = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('DioException: ', '');
      final sepIdx   = raw.indexOf('::');
      final httpCode = sepIdx > 0 ? int.tryParse(raw.substring(0, sepIdx)) ?? 0 : 0;
      final msg      = sepIdx > 0 ? raw.substring(sepIdx + 2) : raw;


      // â”€â”€ UFR_48: System error â†’ retry up to 5 times â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      if (_isSystemError(msg)) {
        final currentRetries = _retryCount[scannedToken] ?? 0;
        if (currentRetries < _maxRetries) {
          _retryCount[scannedToken] = currentRetries + 1;
          final remaining = _maxRetries - currentRetries - 1;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.wifi_off_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'System error â€” retrying... '
                  '(attempt ${currentRetries + 1}/$_maxRetries, '
                  '$remaining retries left)',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4))),
              ]),
              backgroundColor: const Color(0xFFD97706),
              behavior:        SnackBarBehavior.floating,
              margin:          const EdgeInsets.fromLTRB(16, 0, 16, 24),
              duration:        const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ));
            setState(() { _isScanning = false; _lastScannedValue = null; });
            await _restartCamera();
          }
          return;
        } else {
          // Exhausted all 5 retries
          _retryCount.remove(scannedToken);
          await _navigateError(
              'System error after $_maxRetries attempts.\n'
              'Please contact support â€” this is not a passenger issue.');
          return;
        }
      }

      // â”€â”€ Business logic errors â€” no retry â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

      // 409 = passenger already on board â†’ auto-switch to alighting
      final is409 = httpCode == 409;
      if (is409) {
        try {
          final result = await widget.api.scanExit(scannedToken);
          _tokenScanHistory.remove(scannedToken);
          setState(() { _scanCount++; });
          if (!mounted) return;
          await Navigator.push<bool>(context,
              MaterialPageRoute(
                  builder: (_) => ScanSuccessScreen(result: result)));
          if (mounted) {
            setState(() { _isScanning = false; _lastScannedValue = null; });
            await _restartCamera();
          }
        } catch (exitErr) {
          await _navigateError(
              'Passenger already on board but exit scan also failed.\n'
              'Please check the system.');
        }
        return;
      }

      // 410 = QR expired (UFR_48: clear history so next scan goes to scan-IN)
      final is410 = httpCode == 410;
      if (is410) {
        // CRITICAL: clear token history so next scan attempts scan-IN (not scan-EXIT)
        // This ensures UFR_48 attempt counter is hit on repeated scans
        _tokenScanHistory.remove(scannedToken);

        if (mounted) {
          final isAttemptMsg = msg.contains('attempt') || msg.contains('remaining');
          final displayMsg   = isAttemptMsg ? msg : 'QR expired. Ask passenger to refresh their QR card.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              Icon(isAttemptMsg ? Icons.warning_amber_rounded : Icons.refresh_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(displayMsg,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
            ]),
            backgroundColor: isAttemptMsg ? const Color(0xFFD97706) : const Color(0xFF1A6FA8),
            behavior: SnackBarBehavior.floating,
            margin:   const EdgeInsets.fromLTRB(16, 0, 16, 24),
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
          setState(() { _isScanning = false; _lastScannedValue = null; });
          await _restartCamera();
        }
        return;
      }

      // 429 = UFR_48 lockout — show prominent error
      final is429 = httpCode == 429;
      if (is429) {
        final lockMsg = msg
            .replaceFirst('Exception: ', '')
            .replaceFirst('DioException: ', '');
        await _navigateError('🔒 Scanning Locked\n\n$lockMsg');
        return;
      }

      await _navigateError(msg);
    }
  }

  Future<void> _navigateError(String message) async {
    if (!mounted) return;
    try { await _cameraCtrl.stop(); } catch (_) {}
    await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ScanErrorScreen(errorMessage: message)));
    if (!mounted) return;
    setState(() { _isScanning = false; _lastScannedValue = null; });
    await _restartCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040A14),
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(child: _buildViewfinder()),
          _buildBottomPanel(),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.95),
        border: Border(bottom: BorderSide(color: _cyan.withOpacity(0.1))),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: Colors.white70),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('BUSGO Scanner', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Auto-detects boarding & alighting',
              style: GoogleFonts.inter(
                  fontSize: 12, color: _cyan.withOpacity(0.7))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _cyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cyan.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.qr_code_scanner, size: 14, color: _cyan),
            const SizedBox(width: 6),
            Text('$_scanCount scanned', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: _cyan)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildViewfinder() {
    return Stack(fit: StackFit.expand, children: [
      MobileScanner(controller: _cameraCtrl, onDetect: _onDetect),
      LayoutBuilder(builder: (ctx, constraints) {
        const boxSize = 260.0;
        final left = (constraints.maxWidth - boxSize) / 2;
        final top  = (constraints.maxHeight - boxSize) / 2;

        return Stack(children: [
          Positioned(top: 0, left: 0, right: 0, height: top,
              child: Container(color: const Color(0xDD040A14))),
          Positioned(bottom: 0, left: 0, right: 0,
              height: constraints.maxHeight - top - boxSize,
              child: Container(color: const Color(0xDD040A14))),
          Positioned(top: top, left: 0, width: left, height: boxSize,
              child: Container(color: const Color(0xDD040A14))),
          Positioned(top: top, right: 0, width: left, height: boxSize,
              child: Container(color: const Color(0xDD040A14))),

          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) {
              final glow = _pulseAnim.value;
              return Stack(children: [
                Positioned(top: top,  left:  left,  child: _glowCorner(0, glow)),
                Positioned(top: top,  right: left,  child: _glowCorner(1, glow)),
                Positioned(bottom: constraints.maxHeight - top - boxSize,
                    left: left,  child: _glowCorner(2, glow)),
                Positioned(bottom: constraints.maxHeight - top - boxSize,
                    right: left, child: _glowCorner(3, glow)),
              ]);
            },
          ),

          Positioned(
            top: top, left: left, width: boxSize, height: boxSize,
            child: AnimatedBuilder(
              animation: _scanLineAnim,
              builder: (_, __) {
                final lineY = _scanLineAnim.value * boxSize;
                return ClipRect(
                  child: Stack(children: [
                    Positioned(top: 0, left: 0, right: 0, height: lineY,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end:   Alignment.bottomCenter,
                            colors: [
                              _cyan.withOpacity(0.02),
                              _cyan.withOpacity(0.06),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(top: lineY - 4, left: 0, right: 0,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            _cyan.withOpacity(0.8),
                            _cyan,
                            _cyan.withOpacity(0.8),
                            Colors.transparent,
                          ]),
                          boxShadow: [
                            BoxShadow(color: _cyan.withOpacity(0.5),
                                blurRadius: 20, spreadRadius: 4),
                            BoxShadow(color: _cyan.withOpacity(0.3),
                                blurRadius: 40, spreadRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),

          Positioned(top: top, left: left, width: boxSize, height: boxSize,
              child: CustomPaint(painter: _GridPainter())),

          Positioned(bottom: 20, left: 0, right: 0,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628).withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _cyan.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome, size: 14, color: _cyan),
                const SizedBox(width: 8),
                Text('Auto: 1st scan boards Â· 2nd scan alights',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        letterSpacing: 0.3)),
              ]),
            ))),
        ]);
      }),
    ]);
  }

  Widget _glowCorner(int pos, double glow) {
    const size = 30.0;
    return SizedBox(width: size, height: size,
        child: CustomPaint(painter: _GlowCornerPainter(
            pos: pos, glow: glow, color: _cyan)));
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.95),
        border: Border(top: BorderSide(color: _cyan.withOpacity(0.1))),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(_isScanning ? 'Processing...' : 'Ready to scan',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text('Point camera at passenger\'s QR card',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white38)),
        ])),
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape:    BoxShape.circle,
              color:    _cyan.withOpacity(_pulseAnim.value * 0.15),
              border:   Border.all(color: _cyan.withOpacity(0.3)),
              boxShadow: [BoxShadow(
                  color: _cyan.withOpacity(0.2), blurRadius: 12)],
            ),
            child: Icon(
              _isScanning
                  ? Icons.hourglass_top_rounded
                  : Icons.qr_code_scanner,
              color: _cyan, size: 24),
          ),
        ),
      ]),
    );
  }
}

class _GlowCornerPainter extends CustomPainter {
  final int    pos;
  final double glow;
  final Color  color;
  const _GlowCornerPainter(
      {required this.pos, required this.glow, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final top    = pos < 2;
    final isLeft = pos == 0 || pos == 2;
    final paint  = Paint()
      ..color       = color.withOpacity(0.5 + glow * 0.5)
      ..strokeWidth = 3
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    final glowPaint = Paint()
      ..color       = color.withOpacity(glow * 0.3)
      ..strokeWidth = 6
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 4);
    final l = isLeft ? 0.0 : size.width;
    final t = top   ? 0.0 : size.height;
    final r = isLeft ? size.width  * 0.6 : size.width  * 0.4;
    final b = top   ? size.height * 0.6 : size.height * 0.4;
    canvas.drawLine(Offset(l, t), Offset(r, t), glowPaint);
    canvas.drawLine(Offset(l, t), Offset(l, b), glowPaint);
    canvas.drawLine(Offset(l, t), Offset(r, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l, b), paint);
  }

  @override
  bool shouldRepaint(_GlowCornerPainter old) => old.glow != glow;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = const Color(0xFF3FEFEF).withOpacity(0.04)
      ..strokeWidth = 0.5;
    const spacing = 26.0;
    for (double x = spacing; x < size.width;  x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}