import 'package:flutter/material.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/token_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService  _authService;
  final TokenService _tokenService;

  bool       _isLoggedIn  = false;
  bool       _isLoading   = false;
  String?    _errorMessage;
  UserModel? _currentUser;
  String?    _accessToken;
  String?    _recoveryPin;

  // Forgot password state
  String _forgotEmail  = '';
  String _resetToken   = '';
  int    _forgotPasswordStep = 0;

  // Email verification state
  String? _pendingVerificationEmail;
  String? get pendingVerificationEmail => _pendingVerificationEmail;

  AuthProvider(this._authService, this._tokenService);

  bool       get isLoggedIn         => _isLoggedIn;
  bool       get isLoading          => _isLoading;
  String?    get errorMessage       => _errorMessage;
  UserModel? get currentUser        => _currentUser;
  String?    get accessToken        => _accessToken;
  String?    get recoveryPin        => _recoveryPin;
  int        get forgotPasswordStep => _forgotPasswordStep;
  String     get forgotEmail        => _forgotEmail;

  Future<void> checkSession() async {
    final accessToken = await _tokenService.getAccessToken();
    if (accessToken == null) {
      _isLoggedIn = false;
      notifyListeners();
      return;
    }
    try {
      _currentUser = await _authService.getMe();
      _accessToken = await _tokenService.getAccessToken();
      if (_currentUser != null && _currentUser!.role != 'passenger') {
        await _authService.logout();
        _isLoggedIn  = false;
        _currentUser = null;
        _accessToken = null;
        notifyListeners();
        return;
      }
      _isLoggedIn = true;
    } catch (_) {
      _isLoggedIn = false;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await _authService.login(email, password);
      _accessToken = await _tokenService.getAccessToken();
      if (_currentUser != null && _currentUser!.role != 'passenger') {
        await _authService.logout();
        _currentUser  = null;
        _accessToken  = null;
        _isLoggedIn   = false;
        _isLoading    = false;
        _errorMessage = 'LOGIN_RESTRICTED';
        notifyListeners();
        return false;
      }
      _isLoggedIn = true;
      _isLoading  = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String username,
    required String phone,
    required String password,
    String? dateOfBirth,
    required String answer1,
    required String answer2,
    required String answer3,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final pin = await _authService.register(
        fullName:    fullName,
        email:       email,
        username:    username,
        phone:       phone,
        password:    password,
        dateOfBirth: dateOfBirth,
        answer1:     answer1,
        answer2:     answer2,
        answer3:     answer3,
      );
      _recoveryPin              = pin;
      _pendingVerificationEmail = email;
      _isLoading                = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyEmail(String email, String pin) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await _authService.verifyEmail(email, pin);
      _accessToken = await _tokenService.getAccessToken();
      _isLoggedIn  = true;
      _pendingVerificationEmail = null;
      _isLoading   = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendVerificationPin(String email) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.resendVerificationPin(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  // ── Forgot Password Flow ──────────────────────────────────────────────────

  Future<bool> sendResetPin(String email) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.requestResetPin(email);
      _forgotEmail        = email;
      _forgotPasswordStep = 1;
      _isLoading          = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _resetToken         = await _authService.verifyResetPin(_forgotEmail, pin);
      _forgotPasswordStep = 2;
      _isLoading          = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  // ── NEW: Passenger identity verification via recovery PIN + answers ────────

  Future<bool> verifyIdentity({
    required String email,
    required String recoveryPin,
    required String answer1,
    required String answer2,
    required String answer3,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _resetToken = await _authService.verifyIdentity(
        email:       email,
        recoveryPin: recoveryPin,
        answer1:     answer1,
        answer2:     answer2,
        answer3:     answer3,
      );
      _forgotEmail        = email;
      _forgotPasswordStep = 3;
      _isLoading          = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String newPassword, String confirmPassword) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    if (newPassword.length < 8) {
      _isLoading    = false;
      _errorMessage = 'Password must be at least 8 characters.';
      notifyListeners();
      return false;
    }
    if (newPassword != confirmPassword) {
      _isLoading    = false;
      _errorMessage = 'Passwords do not match.';
      notifyListeners();
      return false;
    }
    try {
      await _authService.resetPassword(
        resetToken:      _resetToken,
        newPassword:     newPassword,
        confirmPassword: confirmPassword,
      );
      resetForgotPassword();
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  void resetForgotPassword() {
    _forgotPasswordStep = 0;
    _forgotEmail        = '';
    _resetToken         = '';
    _errorMessage       = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try { await _authService.logout(); } catch (_) {}
    _isLoggedIn  = false;
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void updateCurrentUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<String?> getAccessToken() => _tokenService.getAccessToken();

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final ok = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword:     newPassword,
      );
      _isLoading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _isLoading    = false;
      _errorMessage = 'Failed to change password';
      notifyListeners();
      return false;
    }
  }
}