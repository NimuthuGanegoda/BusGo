import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants/app_colors.dart';

class LiveMapWidget extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<LatLng> routePolyline;
  final List<LatLng> stopLocations;
  final List<String> stopNames;
  final LatLng? busLocation;
  final int? currentStopIndex;

  const LiveMapWidget({
    super.key, required this.center, this.zoom = 13.5,
    this.routePolyline = const [], this.stopLocations = const [],
    this.stopNames = const [], this.busLocation, this.currentStopIndex,
  });

  @override
  Widget build(BuildContext context) => FlutterMap(
    options: MapOptions(initialCenter: center, initialZoom: zoom,
      interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate)),
    children: [
      TileLayer(urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=fsVEp87wcHaGchb3gygh',
          userAgentPackageName: 'com.busgo.drive'),
      if (routePolyline.isNotEmpty) PolylineLayer(polylines: [
        Polyline(points: routePolyline, strokeWidth: 4, color: AppColors.mapRoute),
      ]),
      if (stopLocations.isNotEmpty) MarkerLayer(markers: List.generate(stopLocations.length, (i) {
        final isCompleted = currentStopIndex != null && i < currentStopIndex!;
        final isCurrent   = currentStopIndex != null && i == currentStopIndex;
        return Marker(point: stopLocations[i], width: isCurrent ? 28 : 20, height: isCurrent ? 28 : 20,
          child: Container(
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.success : isCurrent ? AppColors.warning : AppColors.mapStop,
              shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
            child: Center(child: Text('${i+1}', style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)))));
      })),
      if (busLocation != null) MarkerLayer(markers: [
        Marker(point: busLocation!, width: 40, height: 40,
          child: Container(
            decoration: BoxDecoration(color: AppColors.mapBus, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3)),
            child: const Icon(Icons.directions_bus, color: Colors.white, size: 18))),
      ]),
    ],
  );
}
