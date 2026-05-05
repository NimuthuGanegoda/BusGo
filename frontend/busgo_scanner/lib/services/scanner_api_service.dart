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




