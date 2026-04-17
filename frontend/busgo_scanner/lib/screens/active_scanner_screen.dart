import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants/app_colors.dart';
import '../services/scanner_api_service.dart';
import '../widgets/scanner_topbar.dart';
import 'scan_success_screen.dart';
import 'scan_error_screen.dart';

enum ScanMode { boarding, alighting }

class ActiveScannerScreen extends StatefulWidget {
  final ScannerApiService api;
  const ActiveScannerScreen({super.key, required this.api});
  @override
  State<ActiveScannerScreen> createState() => _ActiveScannerScreenState();
}

class _ActiveScannerScreenState extends State<ActiveScannerScreen>
    with TickerProviderStateMixin {

  final MobileScannerController _cameraCtrl = MobileScannerController();

  ScanMode  _mode       = ScanMode.boarding;
  bool      _isScanning = false;
  int       _scanCount  = 0;

  Timer?    _debounceTimer;
  String?   _lastScannedValue;
  DateTime? _lastScanTime;

  late AnimationController _scanLineCtrl;
  late Animation<double>   _scanLineAnim;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _cameraCtrl.dispose();
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ── Camera restart helper ─────────────────────────────────────────────────
  Future<void> _restartCamera() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    try { await _cameraCtrl.start(); } catch (_) {}
  }

  // ── Core scan handler ─────────────────────────────────────────────────────
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isScanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final scannedToken = barcode!.rawValue!;

    final now = DateTime.now();
    if (_lastScannedValue == scannedToken &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }
    _lastScannedValue = scannedToken;
    _lastScanTime     = now;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _processScan(scannedToken);
    });
  }

  Future<void> _processScan(String scannedToken) async {
    if (_isScanning) return;

    final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);
    if (!uuidPattern.hasMatch(scannedToken)) {
      await _navigateError(
          'Invalid QR code format.\nPlease ask the passenger to show their BUSGO card.');
      return;
    }

    setState(() => _isScanning = true);
    await _cameraCtrl.stop();

    try {
      final ScanResult result;
      if (_mode == ScanMode.boarding) {
        result = await widget.api.scanIn(scannedToken);
      } else {
        result = await widget.api.scanExit(scannedToken);
      }

      setState(() { _scanCount++; });
      if (!mounted) return;

      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ScanSuccessScreen(result: result)),
      );

      if (mounted) {
        setState(() { _isScanning = false; _lastScannedValue = null; });
        await _restartCamera();
      }

    } catch (e) {
      final msg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('DioException: ', '');

      final is409 = msg.contains('409') || msg.contains('TRIP_ALREADY_ONGOING');
      final is410 = msg.contains('410') || msg.contains('QR_EXPIRED');

      if (is409) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.info_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Passenger already on board.\nSwitch to Alighting mode to scan exit.',
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              )),
            ]),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
          setState(() { _isScanning = false; _lastScannedValue = null; });
          await _restartCamera();
        }
        return;
      }

      if (is410) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                'QR expired.\nAsk passenger to refresh their QR card.',
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              )),
            ]),
            backgroundColor: const Color(0xFF1A6FA8),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            duration: const Duration(seconds: 4),
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

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ScanErrorScreen(errorMessage: message)),
    );

    if (!mounted) return;
    setState(() { _isScanning = false; _lastScannedValue = null; });
    await _restartCamera();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scannerBg,
      body: SafeArea(
        child: Column(children: [
          ScannerTopbar(
              scanCount: _scanCount,
              mode: _mode == ScanMode.boarding ? 'Board' : 'Alight'),
          _modeToggle(),
          Expanded(child: _buildViewfinder()),
          _buildBottomPanel(),
        ]),
      ),
    );
  }

  Widget _modeToggle() => Container(
    color: AppColors.scannerSurface,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(children: [
      Expanded(child: _modeBtn('🟢  Boarding', ScanMode.boarding)),
      const SizedBox(width: 10),
      Expanded(child: _modeBtn('🔴  Alighting', ScanMode.alighting)),
    ]),
  );

  Widget _modeBtn(String label, ScanMode mode) {
    final active = _mode == mode;
    return GestureDetector(
      onTap: () { if (!_isScanning) setState(() => _mode = mode); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryLight
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active
                  ? AppColors.primaryLight
                  : Colors.white.withOpacity(0.15)),
        ),
        child: Center(child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: active
                    ? Colors.white
                    : Colors.white.withOpacity(0.5)))),
      ),
    );
  }

  Widget _buildViewfinder() {
    return Stack(fit: StackFit.expand, children: [
      MobileScanner(controller: _cameraCtrl, onDetect: _onDetect),
      LayoutBuilder(builder: (ctx, constraints) {
        const boxSize = 260.0;
        final left = (constraints.maxWidth  - boxSize) / 2;
        final top  = (constraints.maxHeight - boxSize) / 2;

        return Stack(children: [
          Positioned(top: 0, left: 0, right: 0, height: top,
              child: Container(color: Colors.black54)),
          Positioned(bottom: 0, left: 0, right: 0,
              height: constraints.maxHeight - top - boxSize,
              child: Container(color: Colors.black54)),
          Positioned(top: top, left: 0, width: left, height: boxSize,
              child: Container(color: Colors.black54)),
          Positioned(top: top, right: 0, width: left, height: boxSize,
              child: Container(color: Colors.black54)),
          Positioned(top: top, left: left, child: _corner(0)),
          Positioned(top: top, right: left, child: _corner(1)),
          Positioned(
              bottom: constraints.maxHeight - top - boxSize,
              left: left, child: _corner(2)),
          Positioned(
              bottom: constraints.maxHeight - top - boxSize,
              right: left, child: _corner(3)),
          Positioned(
            top: top, left: left, width: boxSize, height: boxSize,
            child: AnimatedBuilder(
              animation: _scanLineAnim,
              builder: (_, __) => Positioned(
                top: _scanLineAnim.value * (boxSize - 3),
                child: Container(
                  width: boxSize, height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      AppColors.primaryLight.withOpacity(0.8),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]);
      }),
      Positioned(bottom: 20, left: 0, right: 0,
        child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _mode == ScanMode.boarding
                ? const Color(0xFF166534).withOpacity(0.85)
                : const Color(0xFF991B1B).withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _mode == ScanMode.boarding
                ? '🟢 BOARDING MODE' : '🔴 ALIGHTING MODE',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Colors.white)),
        ))),
    ]);
  }

  Widget _corner(int pos) {
    const size = 26.0, thick = 3.0, color = Color(0xFF1976D2);
    final top    = pos < 2;
    final isLeft = pos == 0 || pos == 2;
    return SizedBox(width: size, height: size,
        child: CustomPaint(painter: _CornerPainter(
            top: top, left: isLeft, color: color, thickness: thick)));
  }

  Widget _buildBottomPanel() => Container(
    color: AppColors.scannerSurface,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isScanning ? 'Processing...' : 'Ready to scan',
              style: GoogleFonts.inter(fontSize: 15,
                  fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Point camera at passenger\'s QR card',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.white54)),
        ])),
      AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryLight.withOpacity(_pulseAnim.value * 0.2),
          ),
          child: Icon(
            _isScanning
                ? Icons.hourglass_top_rounded
                : Icons.qr_code_scanner,
            color: Colors.white, size: 26),
        ),
      ),
    ]),
  );
}

// ── Corner painter ────────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final bool top, left;
  final Color color;
  final double thickness;
  const _CornerPainter({
    required this.top,
    required this.left,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = thickness
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    final l = left ? 0.0 : size.width;
    final t = top  ? 0.0 : size.height;
    final r = left ? size.width  * 0.6 : size.width  * 0.4;
    final b = top  ? size.height * 0.6 : size.height * 0.4;
    canvas.drawLine(Offset(l, t), Offset(r, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l, b), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
