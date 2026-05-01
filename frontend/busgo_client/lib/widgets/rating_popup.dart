import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../core/constants/api_constants.dart';
import '../core/constants/app_colors.dart';
import '../models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';

class RatingPopup extends StatefulWidget {
  final TripModel trip;
  const RatingPopup({super.key, required this.trip});

  @override
  State<RatingPopup> createState() => _RatingPopupState();
}

class _RatingPopupState extends State<RatingPopup> {
  final _commentController = TextEditingController();
  bool    _isSubmitting = false;
  bool    _submitted    = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Require a comment
    if (_commentController.text.trim().isEmpty) {
      setState(() => _error = 'Please share your experience');
      return;
    }

    setState(() { _isSubmitting = true; _error = null; });

    try {
      final auth  = context.read<AuthProvider>();
      final token = await auth.getAccessToken();

      // Build body — only include bus_id when it is a real non-empty value
      final Map<String, dynamic> bodyMap = {
        'trip_id': widget.trip.id ?? '',
        'stars':   3,
        'comment': _commentController.text.trim(),
        'tags':    [],
      };
      if (widget.trip.busId != null && widget.trip.busId!.isNotEmpty) {
        bodyMap['bus_id'] = widget.trip.busId;
      }

      debugPrint('[RatingPopup] Submitting: trip=${widget.trip.id} bus=${widget.trip.busId}');

      final res = await http.post(
        Uri.parse('$kBaseUrlDev/ratings'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyMap),
      ).timeout(const Duration(seconds: 15));

      debugPrint('[RatingPopup] Response: ${res.statusCode} ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() { _submitted = true; _isSubmitting = false; });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.read<TripProvider>().clearCompletedTrip();
          Navigator.of(context).pop();
        }
      } else {
        final body = jsonDecode(res.body);
        setState(() {
          _error        = body['message'] ?? 'Failed to submit rating';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      debugPrint('[RatingPopup] Error: $e');
      setState(() {
        _error        = 'Connection error. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _submitted ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 72, height: 72,
        decoration: const BoxDecoration(
            color: Color(0xFF16A34A), shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 40, color: Colors.white)),
      const SizedBox(height: 16),
      Text('Thank you!',
          style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary)),
      const SizedBox(height: 8),
      Text('Your feedback helps improve our service.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textMuted)),
    ],
  );

  Widget _buildForm() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // ── Header ──────────────────────────────────────────────────────────
      Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.star_rounded,
              size: 24, color: AppColors.secondary)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate Your Trip',
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
            Text('How was your journey?',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        )),
        GestureDetector(
          onTap: () {
            context.read<TripProvider>().clearCompletedTrip();
            Navigator.of(context).pop();
          },
          child: const Icon(Icons.close,
              size: 20, color: AppColors.textMuted)),
      ]),
      const SizedBox(height: 20),

      // ── AI banner ────────────────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(children: [
          const Icon(Icons.psychology_rounded,
              size: 16, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Our AI analyses your comment to score the driver fairly.',
            style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.secondary,
                height: 1.4),
          )),
        ]),
      ),
      const SizedBox(height: 16),

      // ── Comment field ────────────────────────────────────────────────────
      Text('YOUR EXPERIENCE',
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.6)),
      const SizedBox(height: 8),
      TextField(
        controller: _commentController,
        maxLines:   4,
        maxLength:  300,
        style: GoogleFonts.inter(
            fontSize: 14, color: AppColors.primary),
        decoration: InputDecoration(
          hintText: 'Tell us about your experience — '
              'was the driver polite? Was the bus clean? '
              'Were you on time?',
          hintStyle: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5),
          filled:     true,
          fillColor:  const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.secondary, width: 2)),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),

      // ── Error ────────────────────────────────────────────────────────────
      if (_error != null) ...[
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.error_outline,
              size: 14, color: AppColors.danger),
          const SizedBox(width: 6),
          Expanded(child: Text(_error!,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.danger))),
        ]),
      ],
      const SizedBox(height: 16),

      // ── Submit button ────────────────────────────────────────────────────
      SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white))
              : Text('Submit Feedback',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 8),

      // ── Skip ─────────────────────────────────────────────────────────────
      Center(child: TextButton(
        onPressed: () {
          context.read<TripProvider>().clearCompletedTrip();
          Navigator.of(context).pop();
        },
        child: Text('Skip for now',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textMuted)),
      )),
    ],
  );
}



