import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Payload received on every bus location broadcast.
class BusLocationUpdate {
  final String busId;
  final double lat;
  final double lng;
  final double? heading;
  final double? speedKmh;
  final String timestamp;

  const BusLocationUpdate({
    required this.busId,
    required this.lat,
    required this.lng,
    this.heading,
    this.speedKmh,
    required this.timestamp,
  });

  factory BusLocationUpdate.fromJson(Map<String, dynamic> json) =>
      BusLocationUpdate(
        busId:     json['bus_id']    as String,
        lat:       (json['lat']      as num).toDouble(),
        lng:       (json['lng']      as num).toDouble(),
        heading:   (json['heading']  as num?)?.toDouble(),
        speedKmh:  (json['speed_kmh'] as num?)?.toDouble(),
        timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      );
}

/// Listens to Supabase Realtime broadcasts from the Node.js backend.
/// The backend calls broadcastToChannel('bus-locations', 'location-update', {...})
/// every time a driver updates their GPS position.
class RealtimeService {
  static const _channelName = 'bus-locations';
  static const _eventName   = 'location-update';

  RealtimeChannel? _channel;
  final _controller = StreamController<BusLocationUpdate>.broadcast();

  /// Stream of live bus location updates.
  Stream<BusLocationUpdate> get locationStream => _controller.stream;

  /// Start listening. Call this once when the map screen is opened.
  void subscribe() {
    _channel = Supabase.instance.client
        .channel(_channelName)
        .onBroadcast(
          event: _eventName,
          callback: (payload) {
            try {
              final update = BusLocationUpdate.fromJson(
                Map<String, dynamic>.from(payload as Map),
              );
              if (!_controller.isClosed) _controller.add(update);
            } catch (e) {
              // Malformed payload — ignore silently
            }
          },
        )
        .subscribe();
  }

  /// Stop listening. Call this when the map screen is disposed.
  Future<void> unsubscribe() async {
    if (_channel != null) {
      await Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
  }

  /// Clean up resources.
  void dispose() {
    unsubscribe();
    _controller.close();
  }
}









