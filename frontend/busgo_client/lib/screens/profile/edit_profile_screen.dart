import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;

  // Password change controllers
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl     = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isSaving        = false;
  bool _isChangingPass  = false;
  bool _obscureCurrent  = true;
  bool _obscureNew      = true;
  bool _obscureConfirm  = true;
  bool _showPassSection = false;

  String? _passError;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _nameController     = TextEditingController(text: user?.fullName    ?? '');
    _usernameController = TextEditingController(text: user?.username    ?? '');
    _phoneController    = TextEditingController(text: user?.phone       ?? '');
    _dobController      = TextEditingController(text: user?.dateOfBirth ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name     = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final phone    = _phoneController.text.trim();

    if (name.isEmpty || username.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in all required fields'),
        backgroundColor: AppColors.danger));
      return;
    }

    setState(() => _isSaving = true);
    final updatedFields = <String, dynamic>{
      'full_name': name,
      'username':  username,
      'phone':     phone,
    };
    final dob = _dobController.text.trim();
    if (dob.isNotEmpty) updatedFields['date_of_birth'] = dob;

    await context.read<UserProvider>().updateProfile(updatedFields);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile updated successfully'),
        backgroundColor: AppColors.success));
      context.pop();
    }
  }

  Future<void> _changePassword() async {
    setState(() => _passError = null);

    final current = _currentPassCtrl.text;
    final newPass  = _newPassCtrl.text;
    final confirm  = _confirmPassCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      setState(() => _passError = 'All password fields are required');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _passError = 'New password must be at least 8 characters');
      return;
    }
    if (newPass != confirm) {
      setState(() => _passError = 'Passwords do not match');
      return;
    }

    setState(() => _isChangingPass = true);

    try {
      final auth = context.read<AuthProvider>();
      final ok   = await auth.changePassword(
          currentPassword: current, newPassword: newPass);

      if (!mounted) return;
      setState(() => _isChangingPass = false);

      if (ok) {
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        setState(() => _showPassSection = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: AppColors.success));
      } else {
        setState(() => _passError = 'Current password is incorrect');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChangingPass = false;
          _passError = 'Failed to change password. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildAvatarSection(),
            const SizedBox(height: 20),
            _buildFormCard(),
            const SizedBox(height: 16),
            _buildPasswordSection(),
            const SizedBox(height: 20),
            _buildSaveButton(),
            const SizedBox(height: 20),
          ]),
        )),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0B1A2E), Color(0xFF132F54), Color(0xFF1E5AA8)]),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
      child: SafeArea(bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Row(children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 20, color: Colors.white))),
            const SizedBox(width: 12),
            const Expanded(child: Text('Edit Profile',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w700, color: Colors.white))),
          ]),
        )),
    );
  }

  Widget _buildAvatarSection() {
    return Consumer<UserProvider>(builder: (_, userProvider, __) {
      final user = userProvider.user;
      return Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.3),
                blurRadius: 12, offset: const Offset(0, 4))]),
          alignment: Alignment.center,
          child: Text(user?.initials ?? '?',
            style: const TextStyle(color: Colors.white,
                fontSize: 28, fontWeight: FontWeight.w700))),
        const SizedBox(height: 10),
        Text(user?.email ?? '',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ]);
    });
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Personal Information',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.primary)),
        const SizedBox(height: 16),
        _buildField(label: 'Full Name',     controller: _nameController,
            icon: Icons.person_outline_rounded),
        const SizedBox(height: 14),
        _buildField(label: 'Username',      controller: _usernameController,
            icon: Icons.alternate_email_rounded),
        const SizedBox(height: 14),
        _buildField(label: 'Phone Number',  controller: _phoneController,
            icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _buildField(label: 'Date of Birth', controller: _dobController,
            icon: Icons.cake_outlined, hint: 'DD/MM/YYYY (optional)'),
      ]),
    );
  }

  // ── Password change section (UFR_18) ──────────────────────────────────────
  Widget _buildPasswordSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(children: [
        // Toggle header — FIX: HitTestBehavior.opaque ensures taps register
        // even on transparent/padding areas of the row
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _showPassSection = !_showPassSection;
            _passError = null;
          }),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 20, color: Color(0xFF1565C0)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Change Password',
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700, color: AppColors.primary))),
              Icon(_showPassSection
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted),
            ]),
          ),
        ),

        if (_showPassSection) ...[
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              _buildPassField('Current Password', _currentPassCtrl,
                  _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent)),
              const SizedBox(height: 14),
              _buildPassField('New Password', _newPassCtrl,
                  _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
              const SizedBox(height: 14),
              _buildPassField('Confirm New Password', _confirmPassCtrl,
                  _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),

              if (_passError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.danger.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        size: 14, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_passError!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.danger))),
                  ])),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 44,
                child: ElevatedButton(
                  onPressed: _isChangingPass ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                  child: _isChangingPass
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Update Password',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildPassField(String label, TextEditingController ctrl,
      bool obscure, VoidCallback toggle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.textMuted)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider)),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 18, color: Color(0xFF1565C0)),
            suffixIcon: GestureDetector(
              onTap: toggle,
              child: Icon(obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
                  size: 18, color: AppColors.textMuted)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 12))),
      ),
    ]);
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.textMuted)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider)),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14,
              color: Colors.white, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 13, color: AppColors.textMuted),
            prefixIcon: Icon(icon, size: 18,
                color: const Color(0xFF1565C0)),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 12)))),
    ]);
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              const Color(0xFF1565C0).withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14))),
        child: _isSaving
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('Save Changes',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600))));
  }
}

