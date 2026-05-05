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
      final msg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('DioException: ', '');

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
      final is409 = msg.contains('409') || msg.contains('TRIP_ALREADY_ONGOING');
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

      // 410 = QR expired (UFR_48: show remaining attempts or lockout)
      final is410 = msg.contains('410') || msg.contains('QR_EXPIRED');
      if (is410) {
        if (mounted) {
          // Check if backend sent a specific UFR_48 message with attempts info
          final isAttemptMsg = msg.contains('attempt') || msg.contains('remaining');
          final displayMsg   = isAttemptMsg
              ? msg.replaceFirst('Exception: ', '')
                   .replaceFirst('DioException: ', '')
              : 'QR expired.\nAsk passenger to refresh their QR card.';

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              Icon(
                isAttemptMsg
                    ? Icons.warning_amber_rounded
                    : Icons.refresh_rounded,
                color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(displayMsg,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4))),
            ]),
            backgroundColor: isAttemptMsg
                ? const Color(0xFFD97706)   // orange for attempt warning
                : const Color(0xFF1A6FA8),  // blue for generic expired
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
      final is429 = msg.contains('429') || msg.contains('SCAN_ATTEMPT_LOCKED');
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


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class ScanErrorScreen extends StatelessWidget {
  final String errorMessage;
  const ScanErrorScreen({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final displayMsg = _friendlyMessage(errorMessage);

    return Scaffold(
      backgroundColor: AppColors.scannerBg,
      body: SafeArea(
        child: Column(children: [
          // â”€â”€ Top bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            color: AppColors.scannerSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              IconButton(
                onPressed: () {
                  if (Navigator.canPop(context)) Navigator.pop(context, false);
                },
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              Text('Scan Failed', style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white)),
            ]),
          ),

          // â”€â”€ Scrollable content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              const SizedBox(height: 24),

              // Error icon
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2), shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.2),
                    blurRadius: 24, spreadRadius: 4,
                  )],
                ),
                child: const Icon(Icons.error_rounded,
                    size: 60, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 24),

              Text('Scan Failed', style: GoogleFonts.inter(
                  fontSize: 24, fontWeight: FontWeight.w800,
                  color: Colors.white)),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(displayMsg, textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14,
                        color: const Color(0xFF991B1B), height: 1.5)),
              ),
              const SizedBox(height: 24),

              // Tips box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text('Common fixes', style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: Colors.white70)),
                  const SizedBox(height: 8),
                  for (final tip in _tips(errorMessage))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('â€¢ ', style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                          Expanded(child: Text(tip, style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.white54))),
                        ]),
                    ),
                ]),
              ),
              const SizedBox(height: 32),

              // Try again button
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: Text('Try Again', style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  if (Navigator.canPop(context)) Navigator.pop(context, false);
                },
                child: Text('Cancel', style: GoogleFonts.inter(
                    color: Colors.white38, fontSize: 14)),
              ),
              const SizedBox(height: 24),
            ]),
          )),
        ]),
      ),
    );
  }

  String _friendlyMessage(String raw) {
    if (raw.contains('INVALID_QR_TOKEN'))
      return 'QR code not recognised.\nThis code does not match any registered passenger.';
    if (raw.contains('QR_EXPIRED'))
      return 'QR code has expired.\nAsk the passenger to open their BUSGO app and refresh the code.';
    if (raw.contains('TRIP_ALREADY_ONGOING'))
      return 'This passenger is already on a trip.\nThey must exit before boarding again.';
    if (raw.contains('ACCOUNT_INACTIVE'))
      return 'Passenger account is inactive.\nPlease ask them to contact support.';
    if (raw.contains('BUS_NOT_RESOLVED'))
      return 'Could not determine your bus.\nMake sure your driver account is assigned to an active bus.';
    if (raw.contains('NO_ONGOING_TRIP'))
      return 'No active trip found for this passenger.\nThey must board before alighting.';
    if (raw.contains('404'))
      return 'QR code not found or already used.\nAsk the passenger to refresh their QR code and try again.';
    if (raw.contains('SocketException') || raw.contains('Connection'))
      return 'Network error.\nCheck your internet connection and try again.';
    return raw.isNotEmpty ? raw : 'An unexpected error occurred. Please try again.';
  }

  List<String> _tips(String raw) {
    if (raw.contains('QR_EXPIRED') || raw.contains('404')) {
      return [
        'Ask passenger to open BUSGO app',
        'Navigate to QR Card screen to refresh',
        'Scan within 5 minutes of refreshing',
      ];
    }
    if (raw.contains('INVALID_QR_TOKEN')) {
      return [
        'Ensure camera is focused on the QR code',
        'The code must be from the BUSGO passenger app',
        'Check if the QR is damaged or unclear',
      ];
    }
    if (raw.contains('SocketException')) {
      return [
        'Check your mobile data or Wi-Fi',
        'Move to an area with better signal',
        'Retry when connection is restored',
      ];
    }
    return [
      'Ensure good lighting when scanning',
      'Hold the phone steady',
      'Ask passenger to increase screen brightness',
    ];
  }
}










import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/scanner_api_constants.dart';

// â”€â”€ Base URL is now read from constants/scanner_api_constants.dart â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// To change the IP: edit kScannerBaseUrl in that file and press R to restart.
// No recompile needed. No --dart-define required.
const _storage = FlutterSecureStorage();

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// QR PAYLOAD â€” FR-34: supports destination stop encoded in QR
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _QrPayload {
  final String  token;
  final String? alightingStopId;
  final String? alightingStopName;

  const _QrPayload({
    required this.token,
    this.alightingStopId,
    this.alightingStopName,
  });

  /// Parse raw QR string.
  /// New format: JSON {"t":"<uuid>","s":"<stopId>","n":"<stopName>"}
  /// Old format: plain UUID string
  factory _QrPayload.fromRaw(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        return _QrPayload(
          token:             json['t'] as String,
          alightingStopId:   json['s'] as String?,
          alightingStopName: json['n'] as String?,
        );
      } catch (_) {}
    }
    return _QrPayload(token: trimmed);
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SCAN RESULT â€” all fields that screens depend on
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class ScanResult {
  final bool   success;
  final String passengerName;
  final String? passengerId;
  final String  message;
  final String? tripId;
  final String? membershipType;

  // Fields used by scan_success_screen.dart
  final bool   isExit;         // true = alighting, false = boarding
  final String status;         // 'PAID' | 'CASH' | 'ALIGHTED'
  final String boardingStop;   // boarding stop name (may be empty)
  final String alightingStop;  // alighting stop name (may be empty)

  // FR-34 express mode info
  final bool isExpressMode;
  final int  activePassengers;
  final int  busCapacity;

  const ScanResult({
    required this.success,
    required this.passengerName,
    this.passengerId,
    required this.message,
    this.tripId,
    this.membershipType,
    this.isExit           = false,
    this.status           = 'PAID',
    this.boardingStop     = '',
    this.alightingStop    = '',
    this.isExpressMode    = false,
    this.activePassengers = 0,
    this.busCapacity      = 50,
  });

  factory ScanResult.boarding(Map<String, dynamic> data, {String alightingStopName = ''}) {
    final passenger = data['passenger'] as Map<String, dynamic>? ?? {};
    return ScanResult(
      success:           true,
      passengerName:     passenger['full_name']       as String? ?? 'Passenger',
      passengerId:       passenger['id']              as String?,
      membershipType:    passenger['membership_type'] as String?,
      message:           data['message']              as String? ?? 'Boarded successfully',
      tripId:            data['trip_id']              as String?,
      isExit:            false,
      status:            'PAID',
      boardingStop:      '',
      alightingStop:     alightingStopName,
      isExpressMode:     data['is_express_mode']    as bool? ?? false,
      activePassengers:  data['active_passengers']  as int?  ?? 0,
      busCapacity:       data['bus_capacity']       as int?  ?? 50,
    );
  }

  factory ScanResult.alighting(Map<String, dynamic> data) {
    final passenger = data['passenger'] as Map<String, dynamic>? ?? {};
    return ScanResult(
      success:           true,
      passengerName:     passenger['full_name'] as String? ?? 'Passenger',
      passengerId:       passenger['id']        as String?,
      message:           data['message']        as String? ?? 'Alighted successfully',
      tripId:            data['trip_id']        as String?,
      isExit:            true,
      status:            'ALIGHTED',
      boardingStop:      '',
      alightingStop:     '',
      isExpressMode:     data['is_express_mode']   as bool? ?? false,
      activePassengers:  data['active_passengers'] as int?  ?? 0,
      busCapacity:       data['bus_capacity']      as int?  ?? 50,
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// TOKEN SERVICE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class ScannerTokenService {
  Future<String?> getAccess() => _storage.read(key: 'scanner_access_token');

  Future<void> saveAccess(String t) =>
      _storage.write(key: 'scanner_access_token', value: t);

  Future<void> clear() => _storage.delete(key: 'scanner_access_token');

  Future<bool> hasSession() async {
    final token = await getAccess();
    return token != null && token.isNotEmpty;
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// API SERVICE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class ScannerApiService {
  final ScannerTokenService _tokenSvc;

  ScannerApiService(this._tokenSvc);

  Future<String?> _token() => _tokenSvc.getAccess();

  // â”€â”€ Driver route ID â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<String?> fetchDriverRouteId() async {
    try {
      final token = await _token();
      if (token == null) return null;

      final res = await http.get(
        Uri.parse('$kScannerBaseUrl/driver/bus'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body    = jsonDecode(res.body) as Map<String, dynamic>;
        final data    = body['data']         as Map<String, dynamic>?;
        final routeId = data?['bus_routes']?['id'] as String?
                     ?? data?['route_id']          as String?;
        debugPrint('[Scanner] Route ID: $routeId');
        return routeId;
      }
      return null;
    } catch (e) {
      debugPrint('[Scanner] Route fetch error: $e');
      return null;
    }
  }

  // â”€â”€ Scan IN (boarding) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<ScanResult> scanIn(String rawQrContent, {String? routeId}) async {
    final payload = _QrPayload.fromRaw(rawQrContent);

    final token = await _token();
    if (token == null) throw Exception('Not authenticated');

    routeId ??= await fetchDriverRouteId();

    final body = <String, dynamic>{
      'scanned_token': payload.token,
      if (routeId                 != null) 'route_id':          routeId,
      if (payload.alightingStopId != null) 'alighting_stop_id': payload.alightingStopId,
    };

    debugPrint('[Scanner] ScanIn â†’ '
        'token=${payload.token.length > 8 ? payload.token.substring(0, 8) : payload.token}... '
        'stop=${payload.alightingStopId ?? 'none'}');

    final res = await http.post(
      Uri.parse('$kScannerBaseUrl/qr/scan-in'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));

    final responseBody = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = responseBody['data'] as Map<String, dynamic>?
                ?? responseBody;
      return ScanResult.boarding(data,
          alightingStopName: payload.alightingStopName ?? '');
    }

    // Throw full message so UFR_48 attempt counts show on scanner screen
    final code    = responseBody['code']    as String? ?? '';
    final message = responseBody['message'] as String? ?? '';
    final fullMsg = message.isNotEmpty ? message : code;
    throw Exception(fullMsg.isNotEmpty ? fullMsg : 'Scan failed (\${res.statusCode})');
  }

  // â”€â”€ Scan EXIT (alighting) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<ScanResult> scanExit(String rawQrContent) async {
    final payload = _QrPayload.fromRaw(rawQrContent);

    final token = await _token();
    if (token == null) throw Exception('Not authenticated');

    debugPrint('[Scanner] ScanExit â†’ '
        'token=${payload.token.length > 8 ? payload.token.substring(0, 8) : payload.token}...');

    final res = await http.post(
      Uri.parse('$kScannerBaseUrl/qr/scan-exit'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({'scanned_token': payload.token}),
    ).timeout(const Duration(seconds: 10));

    final responseBody = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = responseBody['data'] as Map<String, dynamic>?
                ?? responseBody;
      return ScanResult.alighting(data);
    }

    throw Exception(responseBody['message'] ?? 'Exit scan failed (${res.statusCode})');
  }

  // â”€â”€ Login â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$kScannerBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode != 200) {
      throw Exception(body['code'] ?? body['message'] ?? 'Login failed (${res.statusCode})');
    }

    final data = body['data'] as Map<String, dynamic>?;
    final role  = data?['user']?['role'] as String?;

    if (role != 'driver') {
      throw Exception('LOGIN_RESTRICTED');
    }

    final token = data?['access_token'] as String?;
    if (token == null) throw Exception('No token received');
    await _tokenSvc.saveAccess(token);
  }

  // â”€â”€ Logout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> logout() async {
    try {
      final token = await _token();
      if (token != null) {
        await http.post(
          Uri.parse('$kScannerBaseUrl/auth/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type':  'application/json',
          },
        ).timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Best-effort â€” always clear local token regardless
    } finally {
      await _tokenSvc.clear();
    }
  }
}