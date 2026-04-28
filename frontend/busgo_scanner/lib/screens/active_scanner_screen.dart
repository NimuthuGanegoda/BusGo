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

  // Tracks last scan per token for auto boarding/alighting:
  // token → 'boarding' or 'alighting'
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

  // ══════════════════════════════════════════════════════════════════════════
  // AUTO BOARDING / ALIGHTING DETECTION
  //
  // How it works:
  //   1. First scan of a token → Boarding  (POST /payments/verify-scan)
  //   2. Same token scanned again → Alighting  (POST /qr/scan-exit)
  //   3. After alighting, token is reset — next scan of same token = boarding
  //
  // This means the driver NEVER needs to manually switch modes.
  // The scanner automatically knows whether the passenger is boarding or
  // alighting based on their scan history in this session.
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _processScan(String scannedToken) async {
    if (_isScanning) return;

    // Accept either plain UUID or JSON QR payload (FR-34 destination encoding)
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

    // Determine if this is boarding or alighting
    final previousScan = _tokenScanHistory[scannedToken];
    final isExit       = previousScan == 'boarding';

    try {
      final ScanResult result;
      if (isExit) {
        result = await widget.api.scanExit(scannedToken);
        // After alighting, reset so next scan of same token = boarding
        _tokenScanHistory.remove(scannedToken);
      } else {
        result = await widget.api.scanIn(scannedToken);
        // Mark as boarded so next scan = alighting
        _tokenScanHistory[scannedToken] = 'boarding';
      }

      setState(() { _scanCount++; });
      if (!mounted) return;

      await Navigator.push<bool>(context,
          MaterialPageRoute(builder: (_) => ScanSuccessScreen(result: result)));

      if (mounted) {
        setState(() { _isScanning = false; _lastScannedValue = null; });
        await _restartCamera();
      }
    } catch (e) {
      final msg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('DioException: ', '');

      // 409 = passenger already on board → auto-switch to alighting
      final is409 = msg.contains('409') || msg.contains('TRIP_ALREADY_ONGOING');
      if (is409) {
        // Automatically try exit scan
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

      // 410 = QR expired
      final is410 = msg.contains('410') || msg.contains('QR_EXPIRED');
      if (is410) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                  'QR expired.\nAsk passenger to refresh their QR card.',
                  style: TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4))),
            ]),
            backgroundColor: const Color(0xFF1A6FA8),
            behavior:        SnackBarBehavior.floating,
            margin:          const EdgeInsets.fromLTRB(16, 0, 16, 24),
            duration:        const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
          setState(() { _isScanning = false; _lastScannedValue = null; });
          await _restartCamera();
        }
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

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP BAR — no mode toggle needed anymore
  // ═══════════════════════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEWFINDER
  // ═══════════════════════════════════════════════════════════════════════════
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

          // Info badge — shows auto-detect hint
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
                Text('Auto: 1st scan boards · 2nd scan alights',
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

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM PANEL
  // ═══════════════════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════════════════════
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


