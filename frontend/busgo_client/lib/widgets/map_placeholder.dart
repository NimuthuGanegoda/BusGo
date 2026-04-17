import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class MapPlaceholder extends StatelessWidget {
  final double? height;
  final bool showSearchBar;
  final bool showFab;
  final bool showLayerButton;
  final List<MapMarker> busMarkers;
  final List<MapMarker> stopMarkers;
  final MapMarker? userLocation;

  const MapPlaceholder({
    super.key,
    this.height,
    this.showSearchBar = false,
    this.showFab = false,
    this.showLayerButton = false,
    this.busMarkers = const [],
    this.stopMarkers = const [],
    this.userLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFC8D8E4),
            Color(0xFFB0C8D8),
            Color(0xFF9BB8CC),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _MapPainter(),
        child: Stack(
          children: [
            ..._buildRoads(),
            for (final marker in busMarkers)
              Positioned(
                top: marker.top,
                left: marker.left,
                child: const Text('🚌', style: TextStyle(fontSize: 18)),
              ),
            for (final marker in stopMarkers)
              Positioned(
                top: marker.top,
                left: marker.left,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            if (userLocation != null)
              Positioned(
                top: userLocation!.top,
                left: userLocation!.left,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            if (showSearchBar)
              Positioned(
                top: 52,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, size: 18, color: Color(0xFF999999)),
                      SizedBox(width: 8),
                      Text(
                        'Search stops or routes...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (showFab)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            if (showLayerButton)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '🗺 Layers',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 6,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Live Map',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRoads() {
    return [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final w = constraints.maxWidth;
            return Stack(
              children: [
                Positioned(
                  top: h * 0.3,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  top: h * 0.55,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  top: h * 0.75,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 8,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: w * 0.25,
                  child: Container(
                    width: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: w * 0.6,
                  child: Container(
                    width: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: w * 0.8,
                  child: Container(
                    width: 8,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ];
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MapMarker {
  final double top;
  final double left;

  const MapMarker({required this.top, required this.left});
}
