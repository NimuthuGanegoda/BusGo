import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../models/user_model.dart';
import '../services/local_storage_service.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService;

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  bool _busArrivalAlerts = true;
  bool _serviceUpdates = true;
  bool _promotions = false;

  UserProvider(this._userService);

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get busArrivalAlerts => _busArrivalAlerts;
  bool get serviceUpdates => _serviceUpdates;
  bool get promotions => _promotions;

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  void loadPreferences() {
    _busArrivalAlerts = LocalStorageService.getBusArrivalAlerts();
    _serviceUpdates   = LocalStorageService.getServiceUpdates();
    _promotions       = LocalStorageService.getPromotions();
    notifyListeners();
  }

  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _userService.getProfile();
    } on AppException catch (e) {
      _errorMessage = ErrorHandler.userMessage(e);
    } catch (e) {
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> fields) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _userService.updateProfile(fields);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAvatar(Uint8List bytes, String fileName, String mimeType) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final avatarUrl = await _userService.uploadAvatar(bytes, fileName, mimeType);
      if (_user != null) {
        _user = UserModel.fromJson({..._user!.toJson(), 'avatar_url': avatarUrl});
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _isLoading = false;
      _errorMessage = ErrorHandler.userMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = ErrorHandler.userMessage(ErrorHandler.handle(e));
      notifyListeners();
      return false;
    }
  }

  // ── Notification preferences (stored locally) ────────────────────────────

  void toggleBusArrivalAlerts() {
    _busArrivalAlerts = !_busArrivalAlerts;
    LocalStorageService.setBusArrivalAlerts(_busArrivalAlerts);
    notifyListeners();
  }

  void toggleServiceUpdates() {
    _serviceUpdates = !_serviceUpdates;
    LocalStorageService.setServiceUpdates(_serviceUpdates);
    notifyListeners();
  }

  void togglePromotions() {
    _promotions = !_promotions;
    LocalStorageService.setPromotions(_promotions);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  void updateQrToken(String qrToken) {
    if (_user != null) {
      _user = UserModel.fromJson({..._user!.toJson(), 'qr_code': qrToken});
      notifyListeners();
    }
}
}



