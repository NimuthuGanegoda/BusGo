// ═══════════════════════════════════════════════════════════════════════════
// DESTINATION STOP PICKER
// Add this file as: busgo_client/lib/widgets/destination_stop_picker.dart
//
// This bottom sheet is shown when a passenger taps "Board Bus" in the
// route search screen. It lets them pick their alighting stop so the
// driver app can show where passengers need to be dropped off.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class DestinationStopPicker extends StatefulWidget {
  final String routeId;
  final String busNumber;

  const DestinationStopPicker({
    super.key,
    required this.routeId,
    required this.busNumber,
  });

  @override
  State<DestinationStopPicker> createState() => _DestinationStopPickerState();
}

class _DestinationStopPickerState extends State<DestinationStopPicker> {
  List<Map<String, dynamic>> _stops = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    try {
      final auth  = context.read<AuthProvider>();
      final token = await auth.getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      final res = await http.get(
        Uri.parse('$kBaseUrlDev/routes/${widget.routeId}/stops'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        setState(() {
          _stops  = data.whereType<Map<String, dynamic>>().toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Could not load stops'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Handle
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),

        // Title
        Row(children: [
          const Icon(Icons.location_on_rounded,
              color: Color(0xFF3B82F6), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Where are you going?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text('Bus ${widget.busNumber}',
                  style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          )),
        ]),
        const SizedBox(height: 16),

        // Stops list
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 8),
              TextButton(onPressed: () {
                setState(() { _loading = true; _error = null; });
                _loadStops();
              }, child: const Text('Retry')),
            ]))
        else if (_stops.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No stops found for this route.',
                style: TextStyle(color: Colors.white38)))
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _stops.length,
              itemBuilder: (context, index) {
                final stop     = _stops[index];
                final stopId   = stop['id']        as String? ?? '';
                final stopName = stop['stop_name'] as String? ?? 'Stop';

                return InkWell(
                  onTap: () => Navigator.pop(context, {
                    'id':   stopId,
                    'name': stopName,
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('${index + 1}',
                            style: const TextStyle(fontSize: 11,
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.w700))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(stopName,
                          style: const TextStyle(fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500))),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: Colors.white24),
                    ]),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 8),

        // Skip option
        GestureDetector(
          onTap: () => Navigator.pop(context, null),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Skip — board without destination',
                style: TextStyle(fontSize: 13, color: Colors.white38,
                    decoration: TextDecoration.underline)),
          ),
        ),
      ]),
    );
  }
}

/// Show the destination stop picker and return the selected stop.
/// Returns null if user skips or dismisses.
Future<Map<String, dynamic>?> showDestinationPicker(
  BuildContext context, {
  required String routeId,
  required String busNumber,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DestinationStopPicker(
        routeId: routeId, busNumber: busNumber),
  );
}




