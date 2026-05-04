import 'dart:async';
import 'package:flutter/foundation.dart';

class WebSocketService {
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<void> connect(String driverId, String token) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isConnected = true;
    debugPrint('[WS] Connected for driver $driverId');
  }

  void sendLocationUpdate(double lat, double lng, double speed) {
    debugPrint('[WS] Location: $lat, $lng @ ${speed.toStringAsFixed(1)} km/h');
  }

  void disconnect() {
    _isConnected = false;
  }
}









