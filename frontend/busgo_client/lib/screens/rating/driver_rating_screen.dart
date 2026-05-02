import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/trip_provider.dart';

class DriverRatingScreen extends StatefulWidget {
  const DriverRatingScreen({super.key});

  @override
  State<DriverRatingScreen> createState() => _DriverRatingScreenState();
}

class _DriverRatingScreenState extends State<DriverRatingScreen> {
  final _commentController = TextEditingController();
  bool _submitted  = false;
  bool _submitting = false;
  int  _starRating = 3;

  // ── Theme colors ──────────────────────────────────────────────────────────
  static const _bg        = Color(0xFF0D1B2A);
  static const _card      = Color(0xFF132240);
  static const _border    = Color(0xFF1E3A5F);
  static const _accent    = Color(0xFF3B82F6);
  static const _accentSoft = Color(0xFF1D3461);
  static const _textPrimary  = Colors.white;
  static const _textSecondary = Color(0xFF94B4D4);
  static const _textMuted     = Color(0xFF5A7A9A);
  static const _gold      = Color(0xFFF59E0B);
  static const _goldEmpty = Color(0xFF2A3F5F);

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  TextStyle _t({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = _textPrimary,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, _) {
          if (_submitted) return _buildSuccess();
          return Column(children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(children: [
                  _buildTripSummary(tripProvider),
                  const SizedBox(height: 16),
                  _buildStarRating(),
                  const SizedBox(height: 16),
                  _buildQuickTags(tripProvider),
                  const SizedBox(height: 16),
                  _buildComment(tripProvider),
                  const SizedBox(height: 24),
                  _buildActions(tripProvider),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        border: Border(
            bottom: BorderSide(color: _border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: _textPrimary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rate Your Trip',
                    style: _t(size: 17, weight: FontWeight.w700)),
                Text('Help improve our service',
                    style: _t(size: 11, color: _textSecondary)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded, size: 14, color: _gold),
                const SizedBox(width: 4),
                Text('Rate Driver',
                    style: _t(size: 11, weight: FontWeight.w600,
                        color: _textSecondary)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Trip Summary ──────────────────────────────────────────────────────────
  Widget _buildTripSummary(TripProvider tripProvider) {
    final trip = tripProvider.completedTripForRating;
    final routeNumber = trip?.routeNumber ?? '---';
    final from  = trip?.from?.isNotEmpty == true
        ? trip!.from : 'Boarding Stop';
    final to    = trip?.to?.isNotEmpty == true
        ? trip!.to : 'Alighting Stop';
    final fare  = trip?.fare != null && trip!.fare > 0
        ? 'Rs.${trip.fare.toStringAsFixed(0)}' : '—';
    final date  = trip?.date?.isNotEmpty == true ? trip!.date : '';
    final time  = trip?.time?.isNotEmpty == true ? trip!.time : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1E5AA8), Color(0xFF3B82F6)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(routeNumber,
                style: _t(size: 13, weight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('$from → $to',
              style: _t(size: 13, weight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Text(fare,
                style: _t(size: 12, weight: FontWeight.w700,
                    color: _accent)),
          ),
        ]),
        if (date.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(color: _border, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 13, color: _textMuted),
            const SizedBox(width: 6),
            Text('$date${time.isNotEmpty ? '  ·  $time' : ''}',
                style: _t(size: 12, color: _textSecondary)),
          ]),
        ],
      ]),
    );
  }

  // ── Star Rating ───────────────────────────────────────────────────────────
  Widget _buildStarRating() {
    final labels = ['Terrible', 'Bad', 'Okay', 'Good', 'Excellent'];
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFEAB308),
      const Color(0xFF84CC16),
      const Color(0xFF22C55E),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        Text('How was your ride?',
            style: _t(size: 14, color: _textSecondary)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
          final filled = i < _starRating;
          return GestureDetector(
            onTap: () => setState(() => _starRating = i + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 40,
                color: filled ? _gold : _goldEmpty,
              ),
            ),
          );
        })),
        const SizedBox(height: 12),
        Text(
          labels[_starRating - 1],
          style: _t(
              size: 18,
              weight: FontWeight.w700,
              color: colors[_starRating - 1]),
        ),
        const SizedBox(height: 4),
        Text('$_starRating / 5',
            style: _t(size: 12, color: _textMuted)),
      ]),
    );
  }

  // ── Quick Tags ────────────────────────────────────────────────────────────
  Widget _buildQuickTags(TripProvider tripProvider) {
    const tags = [
      'Punctual', 'Safe Driving', 'Friendly',
      'Clean Bus', 'Smooth Ride', 'Helpful',
      'On Time', 'Professional',
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('QUICK TAGS',
          style: _t(size: 11, weight: FontWeight.w700,
              color: _textMuted, letterSpacing: 0.8)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.map((tag) {
          final isSelected = tripProvider.selectedTags.contains(tag);
          return GestureDetector(
            onTap: () => tripProvider.toggleTag(tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _accent.withOpacity(0.15) : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _accent : _border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(tag,
                    style: _t(
                        size: 12,
                        weight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : _textSecondary)),
                if (isSelected) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.check_rounded,
                      size: 13, color: _accent),
                ],
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  // ── Comment ───────────────────────────────────────────────────────────────
  Widget _buildComment(TripProvider tripProvider) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('YOUR EXPERIENCE (optional)',
          style: _t(size: 11, weight: FontWeight.w700,
              color: _textMuted, letterSpacing: 0.8)),
      const SizedBox(height: 10),

      // AI note
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A5C).withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          const Icon(Icons.psychology_rounded,
              size: 16, color: _accent),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Our AI reads your comment to score the driver fairly.',
            style: _t(size: 11, color: _textSecondary, letterSpacing: 0.1),
          )),
        ]),
      ),

      Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: TextField(
          controller:  _commentController,
          maxLines:    4,
          maxLength:   300,
          // ← HIGH CONTRAST: white text on dark field
          style:       _t(size: 14, color: _textPrimary),
          onChanged:   (v) => tripProvider.setComment(v),
          decoration: InputDecoration(
            hintText: 'Was the driver polite? Bus clean? On time?',
            hintStyle: _t(size: 13, color: _textMuted),
            filled:    false,
            border:    InputBorder.none,
            counterStyle: _t(size: 10, color: _textMuted),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ),
    ]);
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Widget _buildActions(TripProvider tripProvider) {
    return Column(children: [
      SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton(
          onPressed: _submitting ? null : () async {
            setState(() => _submitting = true);
            tripProvider.setRating(_starRating);

            final trip = tripProvider.completedTripForRating
                ?? (tripProvider.tripHistory.isNotEmpty
                    ? tripProvider.tripHistory.first
                    : null);

            if (trip?.id != null && trip?.busId != null) {
              await tripProvider.submitRating(
                tripId: trip!.id!,
                busId:  trip.busId!,
              );
            }
            if (mounted) setState(() { _submitted = true; _submitting = false; });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            disabledBackgroundColor: _accent.withOpacity(0.3),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Submit Rating',
                      style: _t(size: 15, weight: FontWeight.w700)),
                ]),
        ),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () {
          tripProvider.clearCompletedTrip();
          context.pop();
        },
        child: Text('Skip for now',
            style: _t(size: 13, color: _textMuted)),
      ),
    ]);
  }

  // ── Success view ──────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1628), Color(0xFF0D2040)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF16A34A).withOpacity(0.5),
                        width: 2),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      size: 50, color: Color(0xFF4ADE80)),
                ),
                const SizedBox(height: 24),
                Text('Thank You!',
                    style: _t(size: 26, weight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  'Your feedback helps improve the\nservice for everyone.',
                  textAlign: TextAlign.center,
                  style: _t(size: 14, color: _textSecondary),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Back to Home',
                        style: _t(size: 15, weight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}






