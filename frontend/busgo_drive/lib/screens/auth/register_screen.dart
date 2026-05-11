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

const List<String> kSriLankaAreas = [
  'Colombo', 'Kandy', 'Galle', 'Negombo', 'Kaduwela', 'Moratuwa',
  'Ratnapura', 'Kurunegala', 'Anuradhapura', 'Trincomalee', 'Batticaloa',
  'Jaffna', 'Matara', 'Hambantota', 'Nuwara Eliya', 'Badulla',
  'Kegalle', 'Kalutara', 'Puttalam', 'Polonnaruwa', 'Ampara',
  'Monaragala', 'Vavuniya', 'Mannar', 'Mullaitivu', 'Kilinochchi',
];

const List<String> _kCommonPasswords = [
  'password', 'password1', 'password123', '123456', '1234567', '12345678',
  '123456789', '1234567890', 'qwerty', 'qwerty123', 'abc123', 'letmein',
  'welcome', 'admin', 'admin123', 'monkey', 'dragon', 'master', 'hello',
  'sunshine', 'princess', 'football', 'iloveyou', 'shadow', 'superman',
  'michael', 'jessica', 'baseball', 'batman', 'trustno1', 'passw0rd',
  'busgo', 'driver', 'driver123', '000000', '111111', '666666', '888888',
];

int _passwordStrength(String pw) {
  if (pw.isEmpty) return 0;
  if (_kCommonPasswords.contains(pw.toLowerCase())) return 1;
  final lower   = RegExp(r'[a-z]').allMatches(pw).length;
  final upper   = RegExp(r'[A-Z]').allMatches(pw).length;
  final numbers = RegExp(r'[0-9]').allMatches(pw).length;
  final special = RegExp(r'[$%^&*!@#()\-_=+\[\]{};:,.<>?]').allMatches(pw).length;
  if (lower < 3 || upper < 3 || numbers < 3 || special < 3) return 1;
  if (pw.length < 12) return 2;
  return 3;
}

String? _validateSLNic(String? value) {
  if (value == null || value.trim().isEmpty) return 'NIC number is required';
  final nic    = value.trim().toUpperCase();
  final oldFmt = RegExp(r'^\d{9}[VX]$');
  final newFmt = RegExp(r'^\d{12}$');
  if (!oldFmt.hasMatch(nic) && !newFmt.hasMatch(nic)) {
    return 'Invalid NIC (e.g. 123456789V or 200012345678)';
  }
  int year;
  int dayOfYear;
  if (oldFmt.hasMatch(nic)) {
    year      = 1900 + int.parse(nic.substring(0, 2));
    dayOfYear = int.parse(nic.substring(2, 5));
  } else {
    year      = int.parse(nic.substring(0, 4));
    dayOfYear = int.parse(nic.substring(4, 7));
  }
  if (dayOfYear > 500) dayOfYear -= 500;
  final birthDate = DateTime(year, 1, 1).add(Duration(days: dayOfYear - 1));
  final now = DateTime.now();
  int age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) age--;
  if (age < 18) return 'Driver must be at least 18 years old (your age: $age)';
  return null;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _phoneController    = TextEditingController();
  final _nicController      = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();
  final _answer1Controller  = TextEditingController();
  final _answer2Controller  = TextEditingController();
  final _answer3Controller  = TextEditingController();

  bool    _obscurePassword       = true;
  bool    _obscureConfirm        = true;
  bool    _isLoading             = false;
  String? _error;
  int     _passwordStrengthLevel = 0;

  final Set<String> _selectedAreas = {};
  String? _areasError;

  File?   _licenseFile;
  bool    _licenseUploading = false;
  String? _licenseUrl;
  String? _licenseError;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(() => _passwordStrengthLevel = _passwordStrength(_passwordController.text));
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nicController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _answer1Controller.dispose();
    _answer2Controller.dispose();
    _answer3Controller.dispose();
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
      child: SafeArea(child: _buildForm()),
    ),
  );

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
    ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset('assets/images/busgo-logo-new.jpeg',
        width: 72, height: 72, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.directions_bus_rounded, size: 36, color: Colors.white))),
    ),
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

      if (_error != null) Container(
        width: double.infinity, padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
        ])),

      Container(
        width: double.infinity, padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: const Color(0xFFFFFDE7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD54F), width: 1)),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFFF57F17)),
          const SizedBox(width: 8),
          Expanded(child: Text('Your account will be reviewed by an admin before you can log in.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF57F17)))),
        ])),

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
          if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
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

      _buildLabel('NIC NUMBER'),
      const SizedBox(height: 4),
      Text('Old format: 123456789V  |  New format: 200012345678',
          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9E9E9E))),
      const SizedBox(height: 6),
      _buildField(controller: _nicController, hint: 'e.g. 123456789V or 200012345678',
        icon: Icons.badge_outlined, keyboardType: TextInputType.text,
        validator: _validateSLNic),
      const SizedBox(height: 20),

      _buildLabel('AREAS OF ROUTE EXPERIENCE'),
      const SizedBox(height: 4),
      Text('Select all areas you have driving experience in',
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9E9E9E))),
      const SizedBox(height: 10),
      _buildAreaChips(),
      if (_areasError != null) ...[
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.danger),
          const SizedBox(width: 4),
          Text(_areasError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
        ]),
      ],
      const SizedBox(height: 20),

      // Password requirements info box
      Container(
        width: double.infinity, padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFCFFE), width: 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lock_outline, size: 14, color: Color(0xFF3B5BDB)),
            const SizedBox(width: 6),
            Text('Password Requirements', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF3B5BDB))),
          ]),
          const SizedBox(height: 6),
          Text(
            '• At least 12 characters\n'
            '• 3 or more lowercase letters\n'
            '• 3 or more uppercase letters\n'
            '• 3 or more numbers (1–9)\n'
            '• 3 or more special characters (\$%^&*)',
            style: GoogleFonts.inter(fontSize: 11,
                color: const Color(0xFF3B5BDB), height: 1.6)),
        ])),

      _buildLabel('PASSWORD'),
      const SizedBox(height: 6),
      _buildField(
        controller: _passwordController,
        hint: 'Min. 12 characters',
        icon: Icons.lock_outline,
        isPassword: true,
        obscure: _obscurePassword,
        onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Password is required';
          if (v.length < 12) return 'Minimum 12 characters required';
          if (_kCommonPasswords.contains(v.toLowerCase())) {
            return 'This password is too common. Choose a stronger one.';
          }
          final lower   = RegExp(r'[a-z]').allMatches(v).length;
          final upper   = RegExp(r'[A-Z]').allMatches(v).length;
          final numbers = RegExp(r'[0-9]').allMatches(v).length;
          final special = RegExp(r'[$%^&*!@#()\-_=+\[\]{};:,.<>?]').allMatches(v).length;
          if (lower   < 3) return 'Need at least 3 lowercase letters';
          if (upper   < 3) return 'Need at least 3 uppercase letters';
          if (numbers < 3) return 'Need at least 3 numbers';
          if (special < 3) return 'Need at least 3 special characters (\$%^&*)';
          return null;
        }),
      if (_passwordController.text.isNotEmpty) ...[
        const SizedBox(height: 8),
        _buildPasswordStrengthIndicator(_passwordStrengthLevel),
      ],
      const SizedBox(height: 14),

      _buildLabel('CONFIRM PASSWORD'),
      const SizedBox(height: 6),
      _buildField(
        controller: _confirmController,
        hint: 'Re-enter password',
        icon: Icons.lock_outline,
        isPassword: true,
        obscure: _obscureConfirm,
        onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Please confirm your password';
          if (v != _passwordController.text) return 'Passwords do not match';
          return null;
        }),
      const SizedBox(height: 20),

      _buildLabel('DRIVER\'S LICENSE PHOTO'),
      const SizedBox(height: 6),
      _buildLicensePicker(),
      const SizedBox(height: 24),

      Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF90CAF9))),
        child: Row(children: [
          const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF1565C0)),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Set up account recovery. A PIN will be shown after '
            'registration — save it along with your answers to '
            'reset your password if needed.',
            style: GoogleFonts.inter(fontSize: 11,
                color: const Color(0xFF1565C0), height: 1.5))),
        ])),

      _buildLabel('Q1: What is your mother\'s maiden name?'),
      const SizedBox(height: 6),
      _buildField(controller: _answer1Controller, hint: 'Your answer',
        icon: Icons.help_outline,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Answer is required' : null),
      const SizedBox(height: 14),

      _buildLabel('Q2: What was the name of your first pet?'),
      const SizedBox(height: 6),
      _buildField(controller: _answer2Controller, hint: 'Your answer',
        icon: Icons.help_outline,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Answer is required' : null),
      const SizedBox(height: 14),

      _buildLabel('Q3: What city were you born in?'),
      const SizedBox(height: 6),
      _buildField(controller: _answer3Controller, hint: 'Your answer',
        icon: Icons.help_outline,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Answer is required' : null),
      const SizedBox(height: 24),

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
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)))),
    ])),
  );

  Widget _buildPasswordStrengthIndicator(int level) {
    final labels = ['', 'Weak', 'Medium', 'Strong'];
    final colors = [Colors.transparent, Colors.red, Colors.orange, Colors.green];
    final label  = labels[level];
    final color  = colors[level];
    String message = '';
    if (level == 1) {
      final pw = _passwordController.text;
      if (_kCommonPasswords.contains(pw.toLowerCase())) {
        message = '⚠ This is a commonly used password';
      } else if (pw.length < 12) {
        message = 'Need at least 12 characters';
      } else {
        final lower   = RegExp(r'[a-z]').allMatches(pw).length;
        final upper   = RegExp(r'[A-Z]').allMatches(pw).length;
        final numbers = RegExp(r'[0-9]').allMatches(pw).length;
        final special = RegExp(r'[$%^&*!@#()\-_=+\[\]{};:,.<>?]').allMatches(pw).length;
        if (lower   < 3) message = 'Need at least 3 lowercase letters';
        else if (upper   < 3) message = 'Need at least 3 uppercase letters';
        else if (numbers < 3) message = 'Need at least 3 numbers';
        else if (special < 3) message = 'Need at least 3 special characters (\$%^&*)';
        else message = 'Password is too weak';
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Row(children: List.generate(3, (i) => Expanded(
          child: Container(
            height: 4, margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
            decoration: BoxDecoration(
                color: i < level ? color : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2))),
        )))),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
      if (message.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(message, style: GoogleFonts.inter(fontSize: 11, color: Colors.red.shade700)),
      ],
    ]);
  }

  Widget _buildAreaChips() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _areasError != null ? AppColors.danger : const Color(0xFFE0E0E0),
            width: 1.5)),
    child: Wrap(
      spacing: 8, runSpacing: 8,
      children: kSriLankaAreas.map((area) {
        final isSelected = _selectedAreas.contains(area);
        return GestureDetector(
          onTap: () => setState(() {
            if (isSelected) _selectedAreas.remove(area);
            else _selectedAreas.add(area);
            _areasError = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? AppColors.primaryLight : const Color(0xFFD0D0D0),
                    width: isSelected ? 1.5 : 1),
                boxShadow: isSelected ? [BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    blurRadius: 4, offset: const Offset(0, 2))] : null),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isSelected) ...[
                const Icon(Icons.check_circle_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(area, style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF4A5568))),
            ]),
          ),
        );
      }).toList(),
    ),
  );

  Widget _buildLicensePicker() {
    final hasImage   = _licenseFile != null;
    final isUploaded = _licenseUrl != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: _licenseUploading ? null : _pickAndUploadLicense,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity, height: 160,
          decoration: BoxDecoration(
              color: isUploaded ? const Color(0xFFE8F5E9)
                  : hasImage ? const Color(0xFFFFF8E1) : const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isUploaded ? AppColors.success
                      : hasImage ? const Color(0xFFFFD54F)
                      : _licenseError != null ? AppColors.danger
                      : const Color(0xFFE0E0E0),
                  width: isUploaded || hasImage ? 2 : 1.5)),
          child: _licenseUploading
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 10),
                  Text('Uploading...', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                ]))
              : hasImage
                  ? Stack(fit: StackFit.expand, children: [
                      ClipRRect(borderRadius: BorderRadius.circular(11),
                          child: Image.file(_licenseFile!, fit: BoxFit.cover)),
                      Positioned(bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                              color: isUploaded
                                  ? AppColors.success.withValues(alpha: 0.9)
                                  : Colors.black.withValues(alpha: 0.5),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(11))),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(isUploaded ? Icons.check_circle_rounded : Icons.upload_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(isUploaded ? 'License uploaded ✓' : 'Tap to upload',
                                style: GoogleFonts.inter(fontSize: 12,
                                    fontWeight: FontWeight.w600, color: Colors.white)),
                          ]))),
                      Positioned(top: 8, right: 8,
                        child: GestureDetector(
                          onTap: _pickAndUploadLicense,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white)))),
                    ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 48, height: 48,
                        decoration: BoxDecoration(color: const Color(0xFFE8EDF2),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.credit_card_rounded,
                            size: 24, color: Color(0xFF9E9E9E))),
                      const SizedBox(height: 10),
                      Text('Tap to take photo or upload',
                          style: GoogleFonts.inter(fontSize: 13,
                              fontWeight: FontWeight.w600, color: const Color(0xFF6B7A8D))),
                      const SizedBox(height: 4),
                      Text('JPG, PNG up to 5MB — Required',
                          style: GoogleFonts.inter(fontSize: 11,
                              color: const Color(0xFFBDBDBD))),
                    ]),
        ),
      ),
      if (_licenseError != null) ...[
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.danger),
          const SizedBox(width: 4),
          Text(_licenseError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
        ]),
      ],
    ]);
  }

  Future<void> _pickAndUploadLicense() async {
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
          source: source, imageQuality: 85, maxWidth: 1920);
      if (picked == null) return;
      final file = File(picked.path);
      setState(() {
        _licenseFile      = file;
        _licenseUrl       = null;
        _licenseError     = null;
        _licenseUploading = true;
      });
      await _uploadLicense(file);
    } catch (e) {
      setState(() {
        _licenseError     = 'Failed to pick image. Please try again.';
        _licenseUploading = false;
      });
    }
  }

  Future<void> _uploadLicense(File file) async {
    setState(() { _licenseUrl = 'pending_upload'; _licenseUploading = false; });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAreas.isEmpty) {
      setState(() => _areasError = 'Please select at least one area of experience');
      return;
    }
    if (_licenseFile == null) {
      setState(() => _licenseError = 'License photo is required');
      return;
    }
    if (_passwordStrengthLevel == 1) {
      setState(() => _error = 'Please choose a stronger password before submitting.');
      return;
    }
    setState(() { _isLoading = true; _error = null; _licenseError = null; _areasError = null; });
    HapticFeedback.lightImpact();

    try {
      final regResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name':        _fullNameController.text.trim(),
          'email':            _emailController.text.trim().toLowerCase(),
          'phone':            _phoneController.text.trim(),
          'password':         _passwordController.text,
          'role':             'driver',
          'membership_type':  'standard',
          'experience_areas': _selectedAreas.toList(),
          'answer_1':         _answer1Controller.text.trim(),
          'answer_2':         _answer2Controller.text.trim(),
          'answer_3':         _answer3Controller.text.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      final regBody = jsonDecode(regResponse.body) as Map<String, dynamic>;

      if (regResponse.statusCode != 201 && regResponse.statusCode != 200) {
        setState(() {
          _error     = regBody['message'] as String? ?? 'Registration failed.';
          _isLoading = false;
        });
        return;
      }

      // Upload license
      try {
        final bytes = await _licenseFile!.readAsBytes();
        final isPng = _licenseFile!.path.toLowerCase().endsWith('.png');
        final ext   = isPng ? 'png' : 'jpg';
        final uploadRequest = http.MultipartRequest(
            'POST', Uri.parse('${ApiConfig.baseUrl}/auth/upload-license'));
        uploadRequest.fields['email'] = _emailController.text.trim().toLowerCase();
        uploadRequest.headers['Accept'] = 'application/json';
        uploadRequest.files.add(http.MultipartFile.fromBytes(
          'license', bytes,
          filename: 'license.$ext',
          contentType: MediaType('image', isPng ? 'png' : 'jpeg'),
        ));
        await uploadRequest.send().timeout(const Duration(seconds: 60));
      } catch (uploadErr) {
        debugPrint('[License Upload] Failed: $uploadErr');
      }

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Application Submitted!',
                    style: GoogleFonts.inter(fontSize: 13,
                        fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Your account is pending admin approval.',
                    style: GoogleFonts.inter(fontSize: 11,
                        color: Colors.white.withOpacity(0.85))),
              ])),
          ]),
          backgroundColor: const Color(0xFF1B5E20),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }

      final data        = regBody['data'] as Map<String, dynamic>?;
      final recoveryPin = data?['recovery_pin'] as String?;

      if (!mounted) return;
      if (recoveryPin != null) {
        context.push('/recovery-pin', extra: recoveryPin);
      } else {
        context.go('/login');
      }

    } catch (e) {
      setState(() {
        _error     = 'Connection failed. Is the backend running?';
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
    controller: controller, obscureText: isPassword && obscure,
    keyboardType: keyboardType, validator: validator,
    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF424242)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFBDBDBD)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFFBDBDBD)),
      suffixIcon: isPassword ? IconButton(
        icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18, color: const Color(0xFFBDBDBD)),
        onPressed: onToggleObscure) : null,
      filled: true, fillColor: const Color(0xFFF5F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border:           OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
      enabledBorder:    OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
      focusedBorder:    OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5)),
      errorBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
    ),
  );
}