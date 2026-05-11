import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/token_service.dart';
import 'package:http_parser/http_parser.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int     _tripCount    = 0;
  double? _mlRating;
  bool    _loadingStats = true;

  List<Map<String, dynamic>> _trips          = [];
  bool _loadingTrips   = true;
  bool _showAllTrips   = false;
  bool _showAllUpdates = false;

  List<Map<String, dynamic>> _serviceUpdates = [];
  bool _loadingUpdates = true;

  bool _uploadingAvatar = false;
  final _picker = ImagePicker();

  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _oldPassCtrl     = TextEditingController();
  final _newPassCtrl     = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureOld  = true;
  bool _obscureNew  = true;
  bool _obscureConf = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchStats(), _fetchTrips(), _fetchServiceUpdates()]);
  }

  Future<String?> _getToken() => TokenService().getAccessToken();

  Future<void> _fetchStats() async {
    try {
      final token = await _getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/driver/rating'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        final rating = (data?['ml_rating'] ?? data?['weighted_rating'] ?? data?['avg_rating']) as num?;
        final total  = (data?['total_trips'] ?? data?['trip_count']) as num?;
        if (mounted) setState(() {
          if (rating != null) _mlRating  = rating.toDouble();
          if (total  != null) _tripCount = total.toInt();
        });
      }
    } catch (e) { debugPrint('[Profile] Stats: $e'); }
    finally { if (mounted) setState(() => _loadingStats = false); }
  }

  Future<void> _fetchTrips() async {
    try {
      final token = await _getToken();
      if (token == null) return;
      for (final url in [
        '${ApiConfig.baseUrl}/driver/trip-history?page=1&page_size=20',
        '${ApiConfig.baseUrl}/trips?status=completed&page=1&page_size=20',
      ]) {
        final res = await http.get(Uri.parse(url),
            headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final data = body['data'];
          List<dynamic> list = [];
          if (data is List) list = data;
          else if (data is Map) list = (data['trips'] as List?) ?? (data['data'] as List?) ?? [];
          if (mounted) setState(() {
            _trips = list.cast<Map<String, dynamic>>();
            if (_trips.isNotEmpty) _tripCount = _trips.length;
          });
          return;
        }
      }
    } catch (e) { debugPrint('[Profile] Trips: $e'); }
    finally { if (mounted) setState(() => _loadingTrips = false); }
  }

  Future<void> _fetchServiceUpdates() async {
    try {
      final token = await _getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notifications?category=service_update'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'];
        List<dynamic> list = [];
        if (data is List) list = data;
        else if (data is Map) list = (data['notifications'] as List?) ?? [];
        if (mounted) setState(() => _serviceUpdates = list.cast<Map<String, dynamic>>());
      }
    } catch (e) { debugPrint('[Profile] Updates: $e'); }
    finally { if (mounted) setState(() => _loadingUpdates = false); }
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Profile Picture', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryLight)),
            title: Text('Take Photo', style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library_rounded, color: AppColors.success)),
            title: Text('Choose from Gallery', style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      )),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 800);
      if (picked == null) return;
      setState(() => _uploadingAvatar = true);
      final token = await _getToken();
      if (token == null) return;
      final bytes = await File(picked.path).readAsBytes();
      final isPng = picked.path.toLowerCase().endsWith('.png');
      final req = http.MultipartRequest(
          'PATCH', Uri.parse('${ApiConfig.baseUrl}/users/me/avatar'));
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(http.MultipartFile.fromBytes(
        'avatar', bytes,
        filename: 'avatar.${isPng ? "png" : "jpg"}',
        contentType: MediaType('image', isPng ? 'png' : 'jpeg'),
      ));
      final response = await req.send().timeout(const Duration(seconds: 30));
      if (mounted) {
        if (response.statusCode == 200) {
          await context.read<AuthProvider>().refreshProfile();
          _showSnack('Profile picture updated ✓', success: true);
        } else {
          _showSnack('Failed to upload. Try again.');
        }
      }
    } catch (e) {
      debugPrint('[Profile] Avatar: $e');
      if (mounted) _showSnack('Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _openEditProfile(String currentName, String currentPhone) {
    _nameCtrl.text  = currentName;
    _phoneCtrl.text = currentPhone;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2))),
          Text('Edit Profile', style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          _darkField(_nameCtrl, 'Full Name', Icons.person_outline),
          const SizedBox(height: 14),
          _darkField(_phoneCtrl, 'Phone Number', Icons.phone_outlined,
              keyboard: TextInputType.phone),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => _saveProfile(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Save Changes', style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700)))),
        ]),
      ),
    );
  }

  Future<void> _saveProfile(BuildContext sheetCtx) async {
    try {
      final token = await _getToken();
      if (token == null) return;
      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/users/me'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'full_name': _nameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim()}),
      ).timeout(const Duration(seconds: 10));
      if (mounted) {
        Navigator.pop(sheetCtx);
        if (res.statusCode == 200) {
          await context.read<AuthProvider>().refreshProfile();
          _showSnack('Profile updated ✓', success: true);
        } else { _showSnack('Failed to update. Try again.'); }
      }
    } catch (e) { if (mounted) _showSnack('Connection error.'); }
  }

  void _openChangePassword() {
    _oldPassCtrl.text = ''; _newPassCtrl.text = ''; _confirmPassCtrl.text = '';
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2))),
          Text('Change Password', style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          _darkPasswordField('Current Password', _oldPassCtrl, _obscureOld,
              () => setS(() => _obscureOld = !_obscureOld)),
          const SizedBox(height: 14),
          _darkPasswordField('New Password', _newPassCtrl, _obscureNew,
              () => setS(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: 14),
          _darkPasswordField('Confirm New Password', _confirmPassCtrl, _obscureConf,
              () => setS(() => _obscureConf = !_obscureConf)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => _changePassword(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Update Password', style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700)))),
        ]),
      )),
    );
  }

  Future<void> _changePassword(BuildContext sheetCtx) async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) { _showSnack('Passwords do not match'); return; }
    if (_newPassCtrl.text.length < 8) { _showSnack('Min 8 characters'); return; }
    try {
      final token = await _getToken();
      if (token == null) return;
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/change-password'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'current_password': _oldPassCtrl.text,
            'new_password': _newPassCtrl.text, 'confirm_password': _confirmPassCtrl.text}),
      ).timeout(const Duration(seconds: 10));
      if (mounted) {
        Navigator.pop(sheetCtx);
        if (res.statusCode == 200) { _showSnack('Password changed ✓', success: true); }
        else {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          _showSnack(body['message'] as String? ?? 'Failed to change password');
        }
      }
    } catch (e) { if (mounted) _showSnack('Connection error.'); }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
      backgroundColor: success ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatDate(String? s) {
    if (s == null) return '—';
    try {
      final dt = DateTime.parse(s).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return s; }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showSnack('Could not open link');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AuthProvider>(builder: (context, auth, _) {
        final driver = auth.driver;
        if (driver == null) return Center(child: Text('Not logged in',
            style: GoogleFonts.inter(color: AppColors.textPrimary)));
        return RefreshIndicator(
          color: AppColors.primaryLight,
          backgroundColor: AppColors.surface,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(children: [

              // ── Header ──────────────────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.divider))),
                child: SafeArea(bottom: false, child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(children: [
                    Stack(alignment: Alignment.bottomRight, children: [
                      GestureDetector(
                        onTap: _uploadingAvatar ? null : _pickAvatar,
                        child: _uploadingAvatar
                            ? Container(width: 88, height: 88,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle, color: AppColors.cardBg),
                                child: const CircularProgressIndicator(
                                    strokeWidth: 2.5, color: AppColors.primaryLight))
                            : CircleAvatar(
                                radius: 44,
                                backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                                backgroundImage: driver.photoUrl.isNotEmpty
                                    ? NetworkImage(driver.photoUrl) : null,
                                child: driver.photoUrl.isEmpty
                                    ? Text(driver.initials, style: GoogleFonts.inter(
                                        fontSize: 30, fontWeight: FontWeight.w800,
                                        color: AppColors.primaryLight))
                                    : null),
                      ),
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 2)),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 14, color: Colors.black)),
                    ]),
                    const SizedBox(height: 14),
                    Text(driver.name, style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(driver.email, style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                )),
              ),

              // ── Stats Row ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  Expanded(child: _statCard(
                    icon: Icons.route_rounded, color: AppColors.primaryLight,
                    value: _loadingStats ? '...' : '$_tripCount', label: 'Total Trips')),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: () => context.push('/rating'),
                    child: _statCard(
                      icon: Icons.star_rounded, color: AppColors.starFilled,
                      value: _mlRating != null ? _mlRating!.toStringAsFixed(1) : 'View',
                      label: 'ML Rating',
                      unit: _mlRating != null ? '/10' : ''))),
                ]),
              ),

              const SizedBox(height: 16),

              // ── Trip History ──────────────────────────────────────────────
              _section(
                title: 'Trip History', icon: Icons.history_rounded,
                child: _loadingTrips
                    ? Center(child: Padding(padding: const EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: AppColors.primaryLight)))
                    : _trips.isEmpty
                        ? _empty('No completed trips yet', 'Your trip history will appear here')
                        : Column(children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primaryLight.withOpacity(0.2))),
                              child: Row(children: [
                                Icon(Icons.info_outline, size: 16,
                                    color: AppColors.primaryLight.withOpacity(0.8)),
                                const SizedBox(width: 8),
                                Text('${_trips.length} trips recorded',
                                    style: GoogleFonts.inter(fontSize: 12,
                                        color: AppColors.primaryLight,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            ),
                            ...(_showAllTrips ? _trips : _trips.take(3)).map(_tripTile),
                            if (_trips.length > 3)
                              TextButton(
                                onPressed: () => setState(() => _showAllTrips = !_showAllTrips),
                                child: Text(
                                  _showAllTrips ? 'Show less' : 'Show all ${_trips.length} trips',
                                  style: GoogleFonts.inter(fontSize: 13,
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.w600))),
                          ]),
              ),

              // ── Service Updates ───────────────────────────────────────────
              _section(
                title: 'Service Updates', icon: Icons.campaign_rounded,
                child: _loadingUpdates
                    ? Center(child: Padding(padding: const EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: AppColors.primaryLight)))
                    : _serviceUpdates.isEmpty
                        ? _empty('No service updates', 'Admin messages will appear here')
                        : Column(children: [
                            ...(_showAllUpdates
                                ? _serviceUpdates
                                : _serviceUpdates.take(3)).map(_updateTile),
                            if (_serviceUpdates.length > 3)
                              TextButton(
                                onPressed: () => setState(() => _showAllUpdates = !_showAllUpdates),
                                child: Text(
                                  _showAllUpdates
                                      ? 'Show less'
                                      : 'Show all ${_serviceUpdates.length} updates',
                                  style: GoogleFonts.inter(fontSize: 13,
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.w600))),
                          ]),
              ),

              // ── Account Settings ──────────────────────────────────────────
              _section(
                title: 'Account Settings', icon: Icons.settings_rounded,
                child: Column(children: [
                  _tile(icon: Icons.person_outline_rounded, label: 'Edit Profile',
                      subtitle: 'Update name and phone number',
                      onTap: () => _openEditProfile(driver.name, driver.phone)),
                  _dividerLine(),
                  _tile(icon: Icons.lock_outline_rounded, label: 'Change Password',
                      subtitle: 'Update your login password',
                      onTap: _openChangePassword),
                ]),
              ),

              // ── Legal & Support ───────────────────────────────────────────
              _section(
                title: 'Legal & Support', icon: Icons.help_outline_rounded,
                child: Column(children: [
                  _tile(icon: Icons.description_outlined, label: 'Terms of Service',
                      onTap: () => _launchUrl('https://busgo.lk/terms')),
                  _dividerLine(),
                  _tile(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy',
                      onTap: () => _launchUrl('https://busgo.lk/privacy')),
                  _dividerLine(),
                  _tile(icon: Icons.headset_mic_outlined, label: 'Help & Support',
                      subtitle: 'Contact us for assistance',
                      onTap: () => _launchUrl('mailto:support@busgo.lk')),
                  _dividerLine(),
                  _tile(icon: Icons.info_outline_rounded, label: 'App Version',
                      subtitle: '1.0.0', onTap: null),
                ]),
              ),

              // ── Sign Out ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: SizedBox(width: double.infinity, height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmSignOut(auth),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text('Sign Out', style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))))),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _statCard({required IconData icon, required Color color,
      required String value, required String label, String unit = ''}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: color)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(value, style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            if (unit.isNotEmpty) Text(unit, style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textMuted)),
          ]),
          Text(label, style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _section({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.primaryLight),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.primaryLight)),
          ]),
        ),
        Divider(height: 1, color: AppColors.divider),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: child),
      ]),
    );
  }

  Widget _tripTile(Map<String, dynamic> trip) {
    final routeName   = (trip['bus_routes'] as Map?)?['route_name'] ?? trip['route_name'] ?? 'Route';
    final routeNum    = (trip['bus_routes'] as Map?)?['route_number'] ?? trip['route_number'] ?? '';
    final origin      = (trip['bus_routes'] as Map?)?['origin'] ?? '';
    final destination = (trip['bus_routes'] as Map?)?['destination'] ?? '';
    final boardedAt   = _formatDate(trip['boarded_at'] as String?);
    final status      = trip['status'] as String? ?? 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.directions_bus_rounded, size: 18,
                color: AppColors.primaryLight)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(routeNum.isNotEmpty ? 'Route $routeNum — $routeName' : routeName,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (origin.isNotEmpty && destination.isNotEmpty)
              Text('$origin → $destination', style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: status == 'completed'
                    ? AppColors.success.withOpacity(0.15)
                    : AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6)),
            child: Text(status.toUpperCase(), style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: status == 'completed' ? AppColors.success : AppColors.warning))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(boardedAt, style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }

  Widget _updateTile(Map<String, dynamic> update) {
    final title  = update['title'] as String? ?? 'Service Update';
    final body   = update['body'] as String? ?? update['message'] as String? ?? '';
    final date   = _formatDate(update['created_at'] as String?);
    final isRead = update['is_read'] as bool? ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? AppColors.cardBg : AppColors.primaryLight.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isRead ? AppColors.border
            : AppColors.primaryLight.withOpacity(0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.campaign_rounded, size: 18, color: AppColors.primaryLight)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            if (!isRead) Container(width: 8, height: 8,
                decoration: BoxDecoration(color: AppColors.primaryLight,
                    shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 4),
          Text(body, style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 6),
          Text(date, style: GoogleFonts.inter(
              fontSize: 10, color: AppColors.textMuted)),
        ])),
      ]),
    );
  }

  Widget _tile({required IconData icon, required String label,
      String? subtitle, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: AppColors.primaryLight)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            if (subtitle != null) Text(subtitle, style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textSecondary)),
          ])),
          if (onTap != null) Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  Widget _empty(String title, String subtitle) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(children: [
      Icon(Icons.inbox_outlined, size: 40, color: AppColors.textMuted),
      const SizedBox(height: 8),
      Text(title, style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(subtitle, style: GoogleFonts.inter(
          fontSize: 12, color: AppColors.textMuted)),
    ]),
  );

  Widget _dividerLine() => Divider(height: 1, color: AppColors.divider, indent: 52);

  Widget _darkField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboard}) =>
    TextField(
      controller: ctrl, keyboardType: keyboard,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
        filled: true, fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
      ),
    );

  Widget _darkPasswordField(String label, TextEditingController ctrl,
      bool obscure, VoidCallback onToggle) =>
    TextField(
      controller: ctrl, obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        prefixIcon: Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: AppColors.textMuted),
          onPressed: onToggle),
        filled: true, fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
      ),
    );

  void _confirmSignOut(AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out', style: GoogleFonts.inter(
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); auth.logout(); context.go('/login'); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}