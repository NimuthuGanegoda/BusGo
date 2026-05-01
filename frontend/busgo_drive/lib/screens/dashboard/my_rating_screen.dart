import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../services/token_service.dart';

class MyRatingScreen extends StatefulWidget {
  const MyRatingScreen({super.key});
  @override State<MyRatingScreen> createState() => _MyRatingScreenState();
}

class _MyRatingScreenState extends State<MyRatingScreen> {
  bool    _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchRating();
  }

  Future<void> _fetchRating() async {
    setState(() { _loading = true; _error = null; });
    final token = await TokenService().getAccessToken();
    if (token == null) {
      setState(() { _error = 'Not logged in'; _loading = false; });
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/driver/rating'),
        headers: { 'Authorization': 'Bearer $token' },
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        setState(() {
          _data = body['data'] as Map<String, dynamic>;
          _loading = false;
        });
      } else {
        setState(() {
          _error = body['message'] ?? 'Failed to load ratings';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error — is the backend running?';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F4F8),
    body: Column(children: [
      _buildHeader(),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : _error != null
              ? _buildError()
              : _buildContent()),
    ]),
  );

  Widget _buildHeader() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF0A2342), Color(0xFF1565C0)],
    )),
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 16,
      bottom: 24, left: 24, right: 24,
    ),
    child: Column(children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
        ),
        child: const Icon(Icons.psychology_rounded, size: 28, color: Colors.white)),
      const SizedBox(height: 12),
      Text('MY RATINGS', style: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: Colors.white, letterSpacing: 2)),
      if (_data?['bus_number'] != null) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Bus ${_data!['bus_number']}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9))),
        ),
      ],
    ]),
  );

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFBDBDBD)),
      const SizedBox(height: 16),
      Text(_error!, textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7A8D))),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _fetchRating,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            foregroundColor: Colors.white),
      ),
    ]),
  ));

  Widget _buildContent() {
    final mlRating  = (_data!['ml_rating']    as num).toDouble();
    final total     = _data!['total_reviews'] as int;
    final recent    = List<Map<String, dynamic>>.from(
        (_data!['recent_ratings'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)));

    return RefreshIndicator(
      onRefresh: _fetchRating,
      color: AppColors.primaryLight,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [

          // ── Main ML score card ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              // Score circle
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: mlRating >= 7
                        ? [const Color(0xFF1565C0), const Color(0xFF1E88E5)]
                        : mlRating >= 5
                            ? [const Color(0xFFF57C00), const Color(0xFFFF9800)]
                            : [const Color(0xFFC62828), const Color(0xFFE53935)],
                  ),
                  boxShadow: [BoxShadow(
                    color: (mlRating >= 7
                        ? const Color(0xFF1565C0)
                        : mlRating >= 5
                            ? const Color(0xFFF57C00)
                            : const Color(0xFFC62828))
                        .withValues(alpha: 0.3),
                    blurRadius: 20, offset: const Offset(0, 8),
                  )],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      mlRating > 0
                          ? mlRating.toStringAsFixed(1)
                          : '--',
                      style: GoogleFonts.inter(
                          fontSize: 36, fontWeight: FontWeight.w800,
                          color: Colors.white, height: 1),
                    ),
                    Text('/10', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Score label
              Text(
                mlRating >= 8 ? 'Excellent' :
                mlRating >= 7 ? 'Good' :
                mlRating >= 5 ? 'Average' :
                mlRating > 0  ? 'Needs Improvement' : 'No Score Yet',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: mlRating >= 7
                        ? const Color(0xFF1565C0)
                        : mlRating >= 5
                            ? const Color(0xFFF57C00)
                            : mlRating > 0
                                ? const Color(0xFFC62828)
                                : const Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 6),
              Text('$total review${total == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF9E9E9E))),
              const SizedBox(height: 16),

              // Score bar
              if (mlRating > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: mlRating / 10,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      mlRating >= 7
                          ? const Color(0xFF1565C0)
                          : mlRating >= 5
                              ? const Color(0xFFF57C00)
                              : const Color(0xFFE53935),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1', style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFFBDBDBD))),
                    Text('5', style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFFBDBDBD))),
                    Text('10', style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFFBDBDBD))),
                  ],
                ),
              ],
            ]),
          ),
          const SizedBox(height: 10),

          // ── AI explanation badge ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBDEFB)),
            ),
            child: Row(children: [
              const Icon(Icons.psychology_rounded,
                  size: 16, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Score is calculated by AI analysis of passenger comments. '
                'Recent comments have higher weight than older ones.',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF5B8DB8),
                    height: 1.4),
              )),
            ]),
          ),

          // ── No reviews / reviews list ─────────────────────────────────────
          if (total == 0) ...[
            const SizedBox(height: 32),
            Center(child: Column(children: [
              const Icon(Icons.rate_review_outlined,
                  size: 48, color: Color(0xFFBDBDBD)),
              const SizedBox(height: 12),
              Text('No reviews yet', style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: const Color(0xFF9E9E9E))),
              const SizedBox(height: 4),
              Text('Ratings from passengers will appear here',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFFBDBDBD))),
            ])),
          ] else ...[
            const SizedBox(height: 18),
            Text('RECENT REVIEWS', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: const Color(0xFF6B7A8D), letterSpacing: 0.8)),
            const SizedBox(height: 10),
            ...recent.map((r) => _buildReviewCard(r)),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> r) {
    final comment   = r['comment'] as String?;
    final mlRating  = r['ml_rating'] as num?;
    final createdAt = r['created_at'] != null
        ? DateTime.tryParse(r['created_at'] as String)
        : null;

    // ML score color
    final scoreColor = mlRating == null
        ? const Color(0xFF9E9E9E)
        : mlRating >= 7
            ? const Color(0xFF1565C0)
            : mlRating >= 5
                ? const Color(0xFFF57C00)
                : const Color(0xFFE53935);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // ML score badge
          if (mlRating != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.psychology_rounded, size: 13, color: scoreColor),
                const SizedBox(width: 4),
                Text('ML ${mlRating.toStringAsFixed(1)}/10',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scoreColor)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('No ML score',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF9E9E9E))),
            ),
          const Spacer(),
          if (createdAt != null)
            Text(_formatDate(createdAt),
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFFBDBDBD))),
        ]),
        if (comment != null && comment.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(comment.trim(), style: GoogleFonts.inter(
              fontSize: 13, color: const Color(0xFF424242), height: 1.4)),
        ],
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0)  return 'Today';
    if (diff.inDays == 1)  return 'Yesterday';
    if (diff.inDays < 7)   return '${diff.inDays}d ago';
    if (diff.inDays < 30)  return '${(diff.inDays / 7).floor()}w ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}







