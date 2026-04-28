import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import 'package:http_parser/http_parser.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _phoneController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool    _obscurePassword = true;
  bool    _obscureConfirm  = true;
  bool    _isLoading       = false;
  String? _error;
  bool    _submitted       = false;

  // License photo
  File?   _licenseFile;
  bool    _licenseUploading = false;
  String? _licenseUrl;
  String? _licenseError;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity, height: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0A2342), Color(0xFF0D2E5C)],
      )),
      child: SafeArea(child: _submitted ? _buildSuccessView() : _buildForm()),
    ),
  );

  // ── Success screen ─────────────────────────────────────────────────────────
  Widget _buildSuccessView() => Center(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
        decoration: const BoxDecoration(color: Color(0xFF1B5E20), shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 44, color: Colors.white)),
      const SizedBox(height: 24),
      Text('Registration Submitted!', textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 12),
      Text(
        'Your application and license have been submitted.\nPlease wait for admin approval before logging in.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF90CAF9), height: 1.6)),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: () => context.go('/login'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Back to Login',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        )),
    ]),
  ));

  // ── Main form ──────────────────────────────────────────────────────────────
  Widget _buildForm() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(children: [
      const SizedBox(height: 40),
      _buildLogo(),
      const SizedBox(height: 28),
      _buildCard(),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: () => context.go('/login'),
        child: RichText(text: TextSpan(children: [
          TextSpan(text: 'Already registered? ',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF90CAF9))),
          TextSpan(text: 'Sign in →',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFD54F))),
        ])),
      ),
      const SizedBox(height: 40),
    ]),
  );

  Widget _buildLogo() => Column(children: [
    Container(width: 72, height: 72,
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.directions_bus_rounded, size: 36, color: Colors.white)),
    const SizedBox(height: 16),
    RichText(text: TextSpan(
        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 3),
        children: const [
          TextSpan(text: 'BUS', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'GO',  style: TextStyle(color: Color(0xFF64B5F6))),
        ])),
    const SizedBox(height: 4),
    Text('DRIVER REGISTRATION', style: GoogleFonts.inter(
        fontSize: 13, color: const Color(0xFF90CAF9), letterSpacing: 2)),
  ]);

  Widget _buildCard() => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Create Account', style: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
      const SizedBox(height: 4),
      Text('Fill in your details to apply as a driver',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9E9E9E))),
      const SizedBox(height: 20),

      // Error banner
      if (_error != null) Container(
        width: double.infinity, padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
        ]),
      ),

      // Pending info banner
      Container(
        width: double.infinity, padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: const Color(0xFFFFFDE7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD54F), width: 1)),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFFF57F17)),
          const SizedBox(width: 8),
          Expanded(child: Text(
              'Your account will be reviewed by an admin before you can log in.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF57F17)))),
        ]),
      ),

      // Form fields
      _buildLabel('FULL NAME'),
      const SizedBox(height: 6),
      _buildField(controller: _fullNameController, hint: 'e.g. Nimal Perera',
        icon: Icons.person_outline,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null),
      const SizedBox(height: 14),

      _buildLabel('EMAIL ADDRESS'),
      const SizedBox(height: 6),
      _buildField(controller: _emailController, hint: 'you@example.com',
        icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Email is required';
          if (!v.contains('@')) return 'Enter a valid email';
          return null;
        }),
      const SizedBox(height: 14),

      _buildLabel('PHONE NUMBER'),
      const SizedBox(height: 6),
      _buildField(controller: _phoneController, hint: '+94 77 123 4567',
        icon: Icons.phone_outlined, keyboardType: TextInputType.phone,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Phone is required';
          if (v.trim().length < 7) return 'Enter a valid phone number';
          return null;
        }),
      const SizedBox(height: 14),

      _buildLabel('PASSWORD'),
      const SizedBox(height: 6),
      _buildField(controller: _passwordController, hint: 'Min. 8 characters',
        icon: Icons.lock_outline, isPassword: true, obscure: _obscurePassword,
        onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Password is required';
          if (v.length < 8) return 'Minimum 8 characters';
          return null;
        }),
      const SizedBox(height: 14),

      _buildLabel('CONFIRM PASSWORD'),
      const SizedBox(height: 6),
      _buildField(controller: _confirmController, hint: 'Re-enter password',
        icon: Icons.lock_outline, isPassword: true, obscure: _obscureConfirm,
        onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Please confirm your password';
          if (v != _passwordController.text) return 'Passwords do not match';
          return null;
        }),
      const SizedBox(height: 20),

      // ── License photo picker ─────────────────────────────────────────────
      _buildLabel('DRIVER\'S LICENSE PHOTO'),
      const SizedBox(height: 6),
      _buildLicensePicker(),
      const SizedBox(height: 24),

      // Submit button
      SizedBox(width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _isLoading
              ? const SizedBox(height: 22, width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text('Submit Application',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        )),
    ])),
  );

  // ── License picker widget ──────────────────────────────────────────────────
  Widget _buildLicensePicker() {
    final hasImage  = _licenseFile != null;
    final hasUrl    = _licenseUrl != null;
    final isUploaded = hasUrl;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: _licenseUploading ? null : _pickAndUploadLicense,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity, height: 160,
          decoration: BoxDecoration(
            color: isUploaded
                ? const Color(0xFFE8F5E9)
                : hasImage ? const Color(0xFFFFF8E1) : const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUploaded
                  ? AppColors.success
                  : hasImage ? const Color(0xFFFFD54F)
                  : _licenseError != null ? AppColors.danger
                  : const Color(0xFFE0E0E0),
              width: isUploaded || hasImage ? 2 : 1.5,
            ),
          ),
          child: _licenseUploading
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 10),
                  Text('Uploading license...', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                ]))
              : hasImage
                  ? Stack(fit: StackFit.expand, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(_licenseFile!, fit: BoxFit.cover)),
                      // Overlay status
                      Positioned(bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isUploaded
                                ? AppColors.success.withValues(alpha: 0.9)
                                : Colors.black.withValues(alpha: 0.5),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(isUploaded ? Icons.check_circle_rounded : Icons.upload_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(isUploaded ? 'License uploaded ✓' : 'Tap to upload',
                                style: GoogleFonts.inter(fontSize: 12,
                                    fontWeight: FontWeight.w600, color: Colors.white)),
                          ]),
                        )),
                      // Retake button
                      Positioned(top: 8, right: 8,
                        child: GestureDetector(
                          onTap: _pickAndUploadLicense,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.refresh_rounded,
                                size: 16, color: Colors.white)))),
                    ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EDF2),
                          borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.credit_card_rounded,
                            size: 24, color: Color(0xFF9E9E9E))),
                      const SizedBox(height: 10),
                      Text('Tap to take photo or upload',
                          style: GoogleFonts.inter(fontSize: 13,
                              fontWeight: FontWeight.w600, color: const Color(0xFF6B7A8D))),
                      const SizedBox(height: 4),
                      Text('JPG, PNG up to 5MB — Required',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFBDBDBD))),
                    ]),
        ),
      ),
      if (_licenseError != null) ...[
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.danger),
          const SizedBox(width: 4),
          Text(_licenseError!,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
        ]),
      ],
    ]);
  }

  // ── Pick image from camera or gallery ─────────────────────────────────────
  Future<void> _pickAndUploadLicense() async {
    // Show bottom sheet to choose source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Upload License Photo', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryLight)),
            title: Text('Take Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text('Use camera', style: GoogleFonts.inter(fontSize: 12)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library_rounded, color: AppColors.success)),
            title: Text('Choose from Gallery',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            subtitle: Text('Pick existing photo', style: GoogleFonts.inter(fontSize: 12)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      )),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        _licenseFile    = file;
        _licenseUrl     = null;
        _licenseError   = null;
        _licenseUploading = true;
      });

      // Upload to backend
      await _uploadLicense(file);
    } catch (e) {
      setState(() {
        _licenseError     = 'Failed to pick image. Please try again.';
        _licenseUploading = false;
      });
    }
  }

  Future<void> _uploadLicense(File file) async {
    try {
      // We upload after registration using a temp endpoint
      // Store file locally — will upload during registration
      setState(() {
        _licenseUrl       = 'pending_upload';
        _licenseUploading = false;
      });
    } catch (e) {
      setState(() {
        _licenseError     = 'Upload failed. Please try again.';
        _licenseUploading = false;
        _licenseUrl       = null;
      });
    }
  }

  // ── Submit registration ────────────────────────────────────────────────────
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // Check license
    if (_licenseFile == null) {
      setState(() => _licenseError = 'License photo is required');
      return;
    }

    setState(() { _isLoading = true; _error = null; _licenseError = null; });
    HapticFeedback.lightImpact();

    try {
      // Step 1 — Register user
      final regResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name':       _fullNameController.text.trim(),
          'email':           _emailController.text.trim().toLowerCase(),
          'phone':           _phoneController.text.trim(),
          'password':        _passwordController.text,
          'role':            'driver',
          'membership_type': 'standard',
        }),
      ).timeout(const Duration(seconds: 10));

      final regBody = jsonDecode(regResponse.body) as Map<String, dynamic>;

      if (regResponse.statusCode != 201 && regResponse.statusCode != 200) {
        setState(() {
          _error = regBody['message'] as String? ?? 'Registration failed.';
          _isLoading = false;
        });
        return;
      }

      // Step 2 — Upload license using a temporary token from registration
      // Since driver is pending, we use a multipart upload with email as identifier
      // Step 2 — Upload license
      final bytes  = await _licenseFile!.readAsBytes();
      final isPng  = _licenseFile!.path.toLowerCase().endsWith('.png');
      final ext    = isPng ? 'png' : 'jpg';

      final uploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/auth/upload-license'),
      );

      uploadRequest.fields['email'] = _emailController.text.trim().toLowerCase();
      uploadRequest.headers['Accept'] = 'application/json';
      uploadRequest.files.add(
        http.MultipartFile.fromBytes(
          'license',
          bytes,
          filename: 'license.$ext',
          contentType: MediaType('image', isPng ? 'png' : 'jpeg'),
        ),
      );

      final uploadRes  = await uploadRequest.send().timeout(const Duration(seconds: 30));
      final uploadBody = await uploadRes.stream.bytesToString();

      if (uploadRes.statusCode != 200 && uploadRes.statusCode != 201) {
        debugPrint('[License Upload] Failed: ${uploadRes.statusCode} $uploadBody');
      }

      setState(() { _submitted = true; _isLoading = false; });
    } catch (e) {
      setState(() {
        _error = 'Connection failed. Is the backend running?';
        _isLoading = false;
      });
    }
  }

  Widget _buildLabel(String text) => Text(text, style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w600,
      color: const Color(0xFF757575), letterSpacing: 0.8));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller:   controller,
    obscureText:  isPassword && obscure,
    keyboardType: keyboardType,
    validator:    validator,
    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF424242)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFBDBDBD)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFFBDBDBD)),
      suffixIcon: isPassword ? IconButton(
        icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18, color: const Color(0xFFBDBDBD)),
        onPressed: onToggleObscure,
      ) : null,
      filled: true, fillColor: const Color(0xFFF5F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
      errorBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger)),
    ),
  );
}



